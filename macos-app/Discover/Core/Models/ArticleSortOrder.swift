import Foundation

/// The user-selectable ordering for the article list (cluster F1).
///
/// This is a **view option**, not schema: the chosen order is persisted in `@AppStorage` by its
/// stable `rawValue` and applied as an in-memory re-sort over the already-filtered
/// `displayedArticles`. The default (`.dateDescending`, newest first) matches the existing
/// `@Query` sort, so the visible order is unchanged until the user picks something else.
///
/// `Sendable`/`Codable` value type; raw values are stable identifiers and must not change
/// (persisted), so new cases append rather than renumber.
enum ArticleSortOrder: String, CaseIterable, Identifiable, Sendable, Codable {
    /// Newest first (publishedAt descending) — the app default, matches the `@Query` sort.
    case dateDescending = "dateDescending"
    /// Oldest first (publishedAt ascending).
    case dateAscending = "dateAscending"
    /// Source name A→Z (then newest-first within a source as a stable tiebreak).
    case sourceAscending = "sourceAscending"

    var id: String { rawValue }

    /// The default order (newest first).
    static let `default` = ArticleSortOrder.dateDescending

    /// Human-readable menu label.
    var label: String {
        switch self {
        case .dateDescending: return "Newest First"
        case .dateAscending:  return "Oldest First"
        case .sourceAscending: return "Source (A–Z)"
        }
    }

    /// SF Symbol shown beside the menu item.
    var systemImage: String {
        switch self {
        case .dateDescending: return "arrow.down"
        case .dateAscending:  return "arrow.up"
        case .sourceAscending: return "textformat.abc"
        }
    }

    /// Pure ordering rule between two articles for this sort order.
    ///
    /// Returns `true` if `lhs` should sort before `rhs`. Total and deterministic: every order
    /// falls back to `publishedAt` descending then the stable `id` so ties never reorder
    /// non-deterministically across renders.
    func areInIncreasingOrder(_ lhs: ArticleModel, _ rhs: ArticleModel) -> Bool {
        switch self {
        case .dateDescending:
            if lhs.publishedAt != rhs.publishedAt { return lhs.publishedAt > rhs.publishedAt }
            return lhs.id < rhs.id
        case .dateAscending:
            if lhs.publishedAt != rhs.publishedAt { return lhs.publishedAt < rhs.publishedAt }
            return lhs.id < rhs.id
        case .sourceAscending:
            let order = lhs.source.localizedCaseInsensitiveCompare(rhs.source)
            if order != .orderedSame { return order == .orderedAscending }
            // Within the same source: newest first, then stable id.
            if lhs.publishedAt != rhs.publishedAt { return lhs.publishedAt > rhs.publishedAt }
            return lhs.id < rhs.id
        }
    }

    /// Returns `articles` re-sorted for this order. Pure; safe to call on the main actor over the
    /// already filtered `displayedArticles`.
    func sorted(_ articles: [ArticleModel]) -> [ArticleModel] {
        articles.sorted(by: areInIncreasingOrder)
    }
}
