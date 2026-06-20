import SwiftUI
import SwiftData

/// The main content panel: hero card + adaptive grid of article cards.
/// Reads live data from SwiftData via `@Query` and refreshes via
/// `ArticleListViewModel` (which delegates network work to `RSSFetcherActor`).
struct ArticleListView: View {

    // MARK: - Inputs

    let selectedCategory: String?

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext

    // MARK: - State
    
    @AppStorage("refreshIntervalMinutes") private var refreshInterval: Int = 30

    @State private var viewModel   = ArticleListViewModel()
    @State private var showFeedMgr = false
    @State private var searchText  = ""
    @State private var setupErrorMessage: String?

    // MARK: - Data (dynamic @Query predicate from selectedCategory)

    @Query private var articles: [ArticleModel]

    /// Total article count across ALL categories — used in .task to decide whether
    /// a refresh is needed.  This prevents category-switching from triggering a
    /// re-fetch just because the selected category has no locally-stored articles yet.
    @Query private var allArticles: [ArticleModel]

    /// All categories — used to build the slug → hex colour lookup for card badges.
    @Query(sort: \CategoryModel.priority) private var allCategories: [CategoryModel]

    /// Enabled feeds and their `lastError` values are used to show offline/failed UI.
    @Query(sort: \FeedModel.name) private var feeds: [FeedModel]

    // Grid layout: adaptive columns, minimum 280 pt wide.
    private let columns = [GridItem(.adaptive(minimum: 280, maximum: 380), spacing: 16)]

    // MARK: - Init (dynamic @Query predicate)

    init(selectedCategory: String?) {
        self.selectedCategory = selectedCategory
        let sort = [SortDescriptor(\ArticleModel.publishedAt, order: .reverse)]
        if let cat = selectedCategory {
            _articles = Query(
                filter: #Predicate<ArticleModel> { $0.category == cat },
                sort: sort
            )
        } else {
            _articles = Query(sort: sort)
        }
    }

    // MARK: - Computed

    /// Slug → hex colour lookup built from persisted CategoryModel rows.
    private var categoryColorMap: [String: String] {
        Dictionary(uniqueKeysWithValues: allCategories.map { ($0.slug, $0.colorHex) })
    }

    /// Articles filtered by the current search query (in-memory, post-@Query).
    private var displayedArticles: [ArticleModel] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return articles }
        return articles.filter {
            $0.title.localizedCaseInsensitiveContains(trimmed) ||
            $0.snippet.localizedCaseInsensitiveContains(trimmed) ||
            $0.source.localizedCaseInsensitiveContains(trimmed)
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    feedStatusBanner
                        .padding(.horizontal, 16)
                }
                if displayedArticles.isEmpty {
                    emptyState
                } else {
                    // Hero card — first (most recent) article.
                    let hero = displayedArticles[0]
                    HeroCardView(
                        article: hero,
                        colorHex: categoryColorMap[hero.category] ?? "#6B7280"
                    )
                    .padding(.horizontal, 16)

                    // Adaptive grid — the rest.
                    if displayedArticles.count > 1 {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(displayedArticles.dropFirst()) { article in
                                ArticleCardView(
                                    article: article,
                                    colorHex: categoryColorMap[article.category] ?? "#6B7280"
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        // Extend content under navigation bar for Liquid Glass scroll-edge effect.
        .scrollContentBackground(.hidden)
        .searchable(text: $searchText, prompt: "Search articles…")
        .navigationTitle(navTitle)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // Mark All Read button
                Button {
                    markAllRead()
                } label: {
                    Label("Mark All Read", systemImage: "checkmark.circle")
                }
                .disabled(displayedArticles.allSatisfy(\.isRead))

                // Feed Manager button
                Button { showFeedMgr = true } label: {
                    Label("Feeds", systemImage: "dot.radiowaves.up.forward")
                }

                // Refresh button
                Button {
                    Task { await viewModel.refresh(context: modelContext) }
                } label: {
                    if viewModel.isRefreshing {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(viewModel.isRefreshing)
            }

            // Last-refreshed timestamp — use the same compact relative format as cards
            if let ts = viewModel.lastRefreshed {
                ToolbarItem(placement: .status) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                            .font(.caption2)
                        TimeAgoText(date: ts)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        // Seed defaults on first launch, then initial fetch + background auto-refresh.
        // Seeding lives here (not in a parent .onAppear) to guarantee it completes
        // before the first fetch — SwiftUI fires child .task before parent .onAppear.
        // We check allArticles (store-wide), not articles (category-filtered), so that
        // switching to an empty category doesn't trigger a redundant full re-fetch.
        .task(id: refreshInterval) {
            do {
                try seedDefaultsIfNeeded()
            } catch {
                setupErrorMessage = error.localizedDescription
                return
            }

            if allArticles.isEmpty {
                await viewModel.refresh(context: modelContext)
            }

            // The .task(id: refreshInterval) restarts this loop whenever the interval changes.
            while !Task.isCancelled {
                if refreshInterval > 0 {
                    try? await Task.sleep(for: .seconds(refreshInterval * 60))
                    guard !Task.isCancelled else { break }
                    await viewModel.refresh(context: modelContext)
                } else {
                    // Auto-refresh is disabled. We just wait indefinitely (the task will be cancelled
                    // and restarted if the interval changes to > 0).
                    try? await Task.sleep(for: .seconds(3600))
                }
            }
        }
        // ⌘R refresh notification
        .onReceive(NotificationCenter.default.publisher(for: .refreshFeeds)) { _ in
            Task { await viewModel.refresh(context: modelContext) }
        }
        // ⌘⇧R force refresh notification
        .onReceive(NotificationCenter.default.publisher(for: .forceRefreshFeeds)) { _ in
            Task { await viewModel.forceRefresh(context: modelContext) }
        }
        // Feed Manager sheet.
        .sheet(isPresented: $showFeedMgr) {
            FeedManagerView()
        }
        // Error alert.
        .alert("Refresh failed", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert("Setup failed", isPresented: Binding(
            get: { setupErrorMessage != nil },
            set: { if !$0 { setupErrorMessage = nil } }
        )) {
            Button("OK") { setupErrorMessage = nil }
        } message: {
            Text(setupErrorMessage ?? "")
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: searchText.isEmpty ? "newspaper" : "magnifyingglass")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text(searchText.isEmpty ? "No articles yet" : "No results for \u{201C}\(searchText)\u{201D}")
                .font(.title2.bold())
            if searchText.isEmpty {
                if isOffline {
                    Text("You appear to be offline. Check your connection and try refreshing.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } else if !failedFeeds.isEmpty {
                    Text("\(failedFeeds.count) feed\(failedFeeds.count == 1 ? "" : "s") failed to refresh. Open Feeds to see which ones.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Tap ⌘R to fetch the latest news from your feeds.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                Button("Refresh Now") {
                    Task { await viewModel.refresh(context: modelContext) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isRefreshing)
                Button("Open Feeds") {
                    showFeedMgr = true
                }
            } else {
                Text("Try a different search term, or clear the search to see all articles.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: - Actions

    private func markAllRead() {
        for article in displayedArticles where !article.isRead {
            article.isRead = true
        }
        do {
            try modelContext.save()
        } catch {
            setupErrorMessage = error.localizedDescription
        }
    }

    // MARK: - First-launch seed

    /// Inserts bundled default categories and feeds into SwiftData on first launch.
    /// Idempotent: inserts missing rows and preserves user changes to existing ones.
    private func seedDefaultsIfNeeded() throws {
        let existingCategories = try modelContext.fetch(FetchDescriptor<CategoryModel>())
        let existingFeeds = try modelContext.fetch(FetchDescriptor<FeedModel>())

        let existingSlugs = Set(existingCategories.map(\.slug))
        let existingUrls = Set(existingFeeds.map(\.url))

        var didInsertAnything = false

        for (index, data) in DefaultFeeds.categories.enumerated() {
            guard !existingSlugs.contains(data.slug) else { continue }
            let category = CategoryModel(
                slug: data.slug,
                label: data.label,
                colorHex: data.color,
                priority: index
            )
            modelContext.insert(category)
            didInsertAnything = true
        }

        for data in DefaultFeeds.feeds {
            guard !existingUrls.contains(data.url) else { continue }
            let feed = FeedModel(
                url: data.url,
                name: data.name,
                category: data.category,
                useOgImage: data.useOgImage
            )
            modelContext.insert(feed)
            didInsertAnything = true
        }

        if didInsertAnything {
            try modelContext.save()
        }
    }

    // MARK: - Feed status

    private var enabledFeeds: [FeedModel] {
        feeds.filter(\.enabled)
    }

    private var failedFeeds: [FeedModel] {
        enabledFeeds.filter { ($0.lastError?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) }
    }

    private var isOffline: Bool {
        guard !enabledFeeds.isEmpty, failedFeeds.count == enabledFeeds.count else { return false }
        return failedFeeds.allSatisfy { ($0.lastError ?? "").localizedCaseInsensitiveContains("offline") }
    }

    @ViewBuilder
    private var feedStatusBanner: some View {
        if !failedFeeds.isEmpty {
            let title = isOffline ? "Offline" : "Some feeds failed"
            let subtitle: String = {
                if isOffline { return "Check your connection and refresh." }
                let count = failedFeeds.count
                let names = failedFeeds.prefix(3).map(\.name)
                let suffix = count > 3 ? " (+\(count - 3) more)" : ""
                return "\(count) failed: \(names.joined(separator: ", "))\(suffix)"
            }()

            HStack(spacing: 10) {
                Image(systemName: isOffline ? "wifi.slash" : "exclamationmark.triangle.fill")
                    .foregroundStyle(isOffline ? Color.secondary : Color.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer(minLength: 8)

                HStack(spacing: 8) {
                    Button {
                        Task { await viewModel.refreshFailedFeeds(context: modelContext) }
                    } label: {
                        if viewModel.isRefreshing {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Retry")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isRefreshing)

                    Button("Feeds") { showFeedMgr = true }
                        .buttonStyle(.bordered)
                }
            }
            .padding(12)
            .glassCard(cornerRadius: 14)
        }
    }

    // MARK: - Helpers

    private var navTitle: String {
        selectedCategory.map { $0.capitalized } ?? "All News"
    }
}
