import Foundation

// MARK: - Search scope

/// The scope a search query is applied within, surfaced via `.searchScopes` (cluster E3).
enum ArticleSearchScope: String, CaseIterable, Identifiable, Sendable {
    /// Match across all currently-loaded articles.
    case all
    /// Restrict to unread articles only.
    case unread
    /// Restrict to the currently-selected category only.
    case thisCategory

    var id: String { rawValue }

    /// Picker label.
    var label: String {
        switch self {
        case .all:          return "All"
        case .unread:       return "Unread"
        case .thisCategory: return "This Category"
        }
    }
}

// MARK: - Article search matcher (pure)

/// A lightweight, value-type snapshot of the searchable fields of an article.
///
/// Used by `ArticleSearchMatcher` so the matching logic can be unit-tested without a
/// `ModelContext` or live `ArticleModel` instances.
struct ArticleSearchSubject: Sendable {
    let title: String
    let snippet: String
    let source: String
    let category: String
    let isRead: Bool

    init(title: String, snippet: String, source: String, category: String, isRead: Bool) {
        self.title = title
        self.snippet = snippet
        self.source = source
        self.category = category
        self.isRead = isRead
    }
}

/// Pure article-search predicate, shared by the in-memory filter path and tests.
///
/// Matching rules (cluster E3):
/// - An empty (whitespace-only) query matches everything (subject to scope).
/// - Otherwise a case-insensitive substring match against title / snippet / source.
/// - `.unread` scope additionally requires `!isRead`.
/// - `.thisCategory` scope additionally requires the subject's category equals `selectedCategory`
///   (when one is selected; a `nil` selected category imposes no extra constraint).
enum ArticleSearchMatcher {

    static func matches(
        _ subject: ArticleSearchSubject,
        query: String,
        scope: ArticleSearchScope,
        selectedCategory: String?
    ) -> Bool {
        // Scope gating first (cheap, no string work for empty queries).
        switch scope {
        case .all:
            break
        case .unread:
            if subject.isRead { return false }
        case .thisCategory:
            if let selected = selectedCategory, subject.category != selected { return false }
        }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }

        return subject.title.localizedCaseInsensitiveContains(trimmed)
            || subject.snippet.localizedCaseInsensitiveContains(trimmed)
            || subject.source.localizedCaseInsensitiveContains(trimmed)
    }
}

// MARK: - Feed search matcher (pure)

/// A value-type snapshot of the searchable fields of a feed.
struct FeedSearchSubject: Sendable {
    let name: String
    let url: String
    let category: String

    init(name: String, url: String, category: String) {
        self.name = name
        self.url = url
        self.category = category
    }
}

/// Pure feed-search predicate used by the Feed Manager's in-memory search.
///
/// An empty (whitespace-only) query matches everything; otherwise a case-insensitive substring
/// match against name / url / category.
enum FeedSearchMatcher {

    static func matches(_ subject: FeedSearchSubject, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }

        return subject.name.localizedCaseInsensitiveContains(trimmed)
            || subject.url.localizedCaseInsensitiveContains(trimmed)
            || subject.category.localizedCaseInsensitiveContains(trimmed)
    }
}

// MARK: - Recent searches store (pure, @AppStorage-backed JSON)

/// Manages a bounded, de-duplicated list of recent search terms stored as JSON in `UserDefaults`
/// (cluster E3). Pure helpers (`adding`, `decode`, `encode`) are unit-testable without a live store.
enum RecentSearchesStore {

    static let maxCount = 8

    /// Returns a new recents array with `term` promoted to the front, de-duplicated
    /// (case-insensitively), and capped at `maxCount`. Empty/whitespace terms are ignored.
    static func adding(_ term: String, to existing: [String]) -> [String] {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return existing }
        var result = existing.filter { $0.caseInsensitiveCompare(trimmed) != .orderedSame }
        result.insert(trimmed, at: 0)
        if result.count > maxCount { result = Array(result.prefix(maxCount)) }
        return result
    }

    /// Decodes a recents array from its JSON string; returns `[]` on any failure (guarded decode).
    static func decode(_ json: String) -> [String] {
        guard let data = json.data(using: .utf8),
              let array = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return array
    }

    /// Encodes a recents array to a JSON string; returns `"[]"` on failure.
    static func encode(_ terms: [String]) -> String {
        guard let data = try? JSONEncoder().encode(terms),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }
}
