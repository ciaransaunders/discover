import Foundation

/// The read-state of one article, reduced to the fields the visibility filter needs.
///
/// A tiny `Sendable` value type so the drop/keep/compose logic can be unit-tested without a
/// `ModelContext` or any SwiftData type. Mirrors the relevant subset of `ArticleModel`.
struct ArticleVisibilitySubject: Sendable, Equatable {
    var isRead: Bool

    init(isRead: Bool) {
        self.isRead = isRead
    }
}

/// Pure, view-layer "hide read articles" filter (cluster C2).
///
/// This intentionally knows nothing about search — callers compose it *after* the search filter so
/// the two stay orthogonal (see `ArticleListView.displayedArticles`). Keeping it pure means the
/// drop/keep/compose/empty-when-all-read behaviour is exhaustively unit-testable.
enum ArticleVisibilityFilter {

    /// Filters `subjects` for display.
    ///
    /// - Parameters:
    ///   - subjects: the already search-filtered articles, in display order.
    ///   - hideRead: when `true`, drop every read article; when `false`, keep all.
    /// - Returns: the indices/order preserved subset to display.
    static func visible<S: Sequence>(_ subjects: S, hideRead: Bool) -> [S.Element]
    where S.Element == ArticleVisibilitySubject {
        guard hideRead else { return Array(subjects) }
        return subjects.filter { !$0.isRead }
    }

    /// Generic variant that projects each element to its read-state via `isRead`.
    ///
    /// Used by `ArticleListView` to filter `[ArticleModel]` directly while sharing the exact same
    /// keep/drop rule that the pure tests exercise above.
    static func visible<Element>(
        _ elements: [Element],
        hideRead: Bool,
        isRead: (Element) -> Bool
    ) -> [Element] {
        guard hideRead else { return elements }
        return elements.filter { !isRead($0) }
    }

    /// Computes the set of feed URLs that still have at least one unread article.
    ///
    /// "Read feed" (cluster C2 `hideReadFeeds`) is defined as a feed whose every article is read —
    /// i.e. a feed URL **absent** from this set. Callers pass the `(feedUrl, isRead)` pairs from a
    /// single grouped fetch so this is O(n) over articles, not one query per feed.
    static func feedURLsWithUnread<S: Sequence>(_ pairs: S) -> Set<String>
    where S.Element == (feedUrl: String?, isRead: Bool) {
        var result = Set<String>()
        for pair in pairs where !pair.isRead {
            if let url = pair.feedUrl, !url.isEmpty {
                result.insert(url)
            }
        }
        return result
    }

    /// Whether a given feed URL currently has any unread articles.
    ///
    /// Convenience over `feedURLsWithUnread`: when `hideReadFeeds` is on, a feed should be hidden
    /// from the sidebar / FeedManager iff this returns `false`.
    static func feedHasUnread(_ feedUrl: String, in unreadFeedURLs: Set<String>) -> Bool {
        unreadFeedURLs.contains(feedUrl)
    }
}
