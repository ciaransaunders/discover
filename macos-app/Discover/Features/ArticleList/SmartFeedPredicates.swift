import Foundation
import SwiftData

/// Builds the SwiftData `#Predicate`s for the smart-feed selections (cluster D) and the folder
/// selection (cluster C3), in one place so the rules are deterministic and testable.
///
/// `ArticleListView.init` builds its `@Query` from these. Each factory captures any `Date`/`Set`
/// into a local `let` *before* the `#Predicate` macro body (the proven `purgeOldArticles` pattern)
/// — the macro body itself never calls `Date.now`/`Calendar`, so tests can inject a fixed `now`.
enum SmartFeedPredicates {

    /// Start of the device-local calendar day containing `now`.
    ///
    /// Exposed (and `now`-injectable) so the "Today" boundary is deterministic in tests.
    static func startOfToday(now: Date = .now, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: now)
    }

    /// `.allUnread` — every unread article.
    static func unread() -> Predicate<ArticleModel> {
        #Predicate<ArticleModel> { !$0.isRead }
    }

    /// `.starred` — every starred article.
    static func starred() -> Predicate<ArticleModel> {
        #Predicate<ArticleModel> { $0.isStarred }
    }

    /// `.today` — articles published on or after the start of today (boundary-inclusive).
    ///
    /// `now` is injectable for deterministic tests; the captured `Date` lives in a `let` outside
    /// the macro body.
    static func today(now: Date = .now, calendar: Calendar = .current) -> Predicate<ArticleModel> {
        let start = startOfToday(now: now, calendar: calendar)
        return #Predicate<ArticleModel> { $0.publishedAt >= start }
    }

    /// `.category(slug)` — articles in a single category.
    static func category(_ slug: String) -> Predicate<ArticleModel> {
        #Predicate<ArticleModel> { $0.category == slug }
    }

    /// `.folder(feedUrls:)` — pure in-memory membership test (FEATURE_PLAN OQ-2 fallback).
    ///
    /// SwiftData's `#Predicate` macro accepts `Array.contains($0.feedUrl ?? "")` at compile time but
    /// **throws an uncaught `NSException` at fetch time** (the optional-coalescing + `CONTAINS`
    /// lowering is unsupported), so folder membership is resolved in memory over an unfiltered
    /// `@Query`. This pure helper keeps the rule unit-testable and is what `ArticleListView`
    /// applies in `displayedArticles`.
    static func articleIsInFolder(_ article: ArticleModel, feedUrls: Set<String>) -> Bool {
        guard let url = article.feedUrl else { return false }
        return feedUrls.contains(url)
    }
}

// MARK: - Navigation title resolution

extension SidebarSelection {

    /// Resolves the navigation title, preferring a stored `CategoryModel.label` /
    /// `FolderModel.name` when available, falling back to `self.title`.
    ///
    /// Pure (takes the two lookups as parameters) so the mapping is unit-testable without SwiftData.
    func resolvedTitle(
        categoryLabel: (String) -> String?,
        folderName: (String) -> String?
    ) -> String {
        switch self {
        case .category(let slug):
            return categoryLabel(slug) ?? title
        case .folder(let slug, _):
            return folderName(slug) ?? title
        default:
            return title
        }
    }
}
