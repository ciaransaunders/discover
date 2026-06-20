import Foundation
import SwiftData

/// App-lifetime background refresh scheduler (cluster E2).
///
/// Replaces the view-scoped `.task(id: refreshInterval)` loop in `ArticleListView` with a single
/// long-lived `Task` started once from `ContentView`'s top-level `.task`. It reads the user's
/// `@AppStorage("refreshIntervalMinutes")` preference, sleeps for that interval, and triggers a
/// refresh via the existing `ArticleListViewModel.refresh(context:)` pipeline.
///
/// `@MainActor` because it drives SwiftData writes via the view model. Network work still happens
/// off-main inside `RSSFetcherActor`.
@MainActor
@Observable
final class RefreshScheduler {

    // MARK: - State

    /// Timestamp of the most recent automatic refresh fired by the scheduler.
    private(set) var lastBackgroundRefresh: Date?

    private var loopTask: Task<Void, Never>?

    /// The view model owning the refresh pipeline. Injected so the scheduler reuses the exact
    /// same fetch → parse → upsert → purge path the UI uses.
    private let viewModel: ArticleListViewModel

    // MARK: - Init

    init(viewModel: ArticleListViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Lifecycle

    /// Starts the long-lived refresh loop. Idempotent: a second call replaces the running loop.
    ///
    /// On first start it performs an initial fetch only if the store is empty (preserving the old
    /// view-scoped behaviour), then loops: sleep → refresh, re-reading the interval each cycle so
    /// a preference change takes effect on the next tick without restarting the task.
    func start(context: ModelContext) {
        loopTask?.cancel()
        loopTask = Task { [weak self] in
            guard let self else { return }

            // Initial fetch only when there is nothing stored yet.
            if Self.storeIsEmpty(context: context) {
                await self.viewModel.refresh(context: context)
            }

            while !Task.isCancelled {
                let minutes = Self.currentIntervalMinutes()
                let delay = Self.nextFireDelay(intervalMinutes: minutes)

                guard let delay else {
                    // Auto-refresh disabled: idle, then re-check (cheap) in case the pref changed.
                    try? await Task.sleep(for: .seconds(3600))
                    continue
                }

                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { break }

                if Self.shouldRefresh(intervalMinutes: Self.currentIntervalMinutes(), isOffline: self.isOffline(context: context)) {
                    let before = Self.articleCount(context: context)
                    await self.viewModel.refresh(context: context)
                    let after = Self.articleCount(context: context)
                    self.lastBackgroundRefresh = .now
                    await NewArticleNotifier.postIfEnabled(newCount: max(0, after - before))
                }
            }
        }
    }

    /// Cancels the running loop (e.g. on scene teardown).
    func stop() {
        loopTask?.cancel()
        loopTask = nil
    }

    // MARK: - Pure helpers (unit-tested)

    /// Seconds to sleep before the next refresh, or `nil` when auto-refresh is disabled.
    ///
    /// - `intervalMinutes <= 0` → `nil` ("Never").
    /// - `intervalMinutes  > 0` → `intervalMinutes × 60`.
    nonisolated static func nextFireDelay(intervalMinutes: Int) -> TimeInterval? {
        guard intervalMinutes > 0 else { return nil }
        return TimeInterval(intervalMinutes * 60)
    }

    /// Whether a scheduled tick should actually refresh.
    ///
    /// - Disabled (`intervalMinutes <= 0`) → `false`.
    /// - Offline → `false` (skip; the next tick retries).
    /// - Otherwise → `true`.
    nonisolated static func shouldRefresh(intervalMinutes: Int, isOffline: Bool) -> Bool {
        guard intervalMinutes > 0 else { return false }
        if isOffline { return false }
        return true
    }

    // MARK: - Private

    private static func currentIntervalMinutes() -> Int {
        // Mirror the @AppStorage default (30) when the key has never been written.
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "refreshIntervalMinutes") != nil else { return 30 }
        return defaults.integer(forKey: "refreshIntervalMinutes")
    }

    private static func storeIsEmpty(context: ModelContext) -> Bool {
        var descriptor = FetchDescriptor<ArticleModel>()
        descriptor.fetchLimit = 1
        let count = (try? context.fetchCount(descriptor)) ?? 0
        return count == 0
    }

    private static func articleCount(context: ModelContext) -> Int {
        (try? context.fetchCount(FetchDescriptor<ArticleModel>())) ?? 0
    }

    /// All enabled feeds currently report an "offline" error → treat the app as offline.
    private func isOffline(context: ModelContext) -> Bool {
        guard let feeds = try? context.fetch(
            FetchDescriptor<FeedModel>(predicate: #Predicate { $0.enabled })
        ), !feeds.isEmpty else { return false }

        let failed = feeds.filter { ($0.lastError?.isEmpty == false) }
        guard failed.count == feeds.count else { return false }
        return failed.allSatisfy { ($0.lastError ?? "").localizedCaseInsensitiveContains("offline") }
    }
}
