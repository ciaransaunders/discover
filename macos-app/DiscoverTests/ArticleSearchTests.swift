import Testing
import Foundation

@testable import Discover

@Suite("Discover — Article Search Matcher")
struct ArticleSearchTests {

    private func subject(
        title: String = "Swift 6 concurrency",
        snippet: String = "Strict actors and sendable types",
        source: String = "The Verge",
        category: String = "tech",
        isRead: Bool = false
    ) -> ArticleSearchSubject {
        ArticleSearchSubject(title: title, snippet: snippet, source: source, category: category, isRead: isRead)
    }

    // MARK: - Empty query

    @Test("Empty query matches everything (All scope)")
    func emptyMatchesAll() {
        #expect(ArticleSearchMatcher.matches(subject(), query: "", scope: .all, selectedCategory: nil))
        #expect(ArticleSearchMatcher.matches(subject(), query: "   ", scope: .all, selectedCategory: nil))
    }

    // MARK: - Field matching (case-insensitive)

    @Test("Case-insensitive title match")
    func titleMatch() {
        #expect(ArticleSearchMatcher.matches(subject(), query: "swift", scope: .all, selectedCategory: nil))
        #expect(ArticleSearchMatcher.matches(subject(), query: "SWIFT", scope: .all, selectedCategory: nil))
    }

    @Test("Case-insensitive snippet match")
    func snippetMatch() {
        #expect(ArticleSearchMatcher.matches(subject(), query: "sendable", scope: .all, selectedCategory: nil))
    }

    @Test("Case-insensitive source match")
    func sourceMatch() {
        #expect(ArticleSearchMatcher.matches(subject(), query: "verge", scope: .all, selectedCategory: nil))
    }

    @Test("No match returns false")
    func noMatch() {
        #expect(!ArticleSearchMatcher.matches(subject(), query: "kotlin", scope: .all, selectedCategory: nil))
    }

    // MARK: - Unread scope

    @Test("Unread scope excludes read articles even with empty query")
    func unreadScopeExcludesRead() {
        #expect(!ArticleSearchMatcher.matches(subject(isRead: true), query: "", scope: .unread, selectedCategory: nil))
        #expect(ArticleSearchMatcher.matches(subject(isRead: false), query: "", scope: .unread, selectedCategory: nil))
    }

    @Test("Unread scope still applies the text filter")
    func unreadScopeWithQuery() {
        #expect(ArticleSearchMatcher.matches(subject(isRead: false), query: "swift", scope: .unread, selectedCategory: nil))
        #expect(!ArticleSearchMatcher.matches(subject(isRead: false), query: "kotlin", scope: .unread, selectedCategory: nil))
    }

    // MARK: - This Category scope

    @Test("This-Category scope excludes other categories")
    func thisCategoryScope() {
        #expect(ArticleSearchMatcher.matches(subject(category: "tech"), query: "", scope: .thisCategory, selectedCategory: "tech"))
        #expect(!ArticleSearchMatcher.matches(subject(category: "ai"), query: "", scope: .thisCategory, selectedCategory: "tech"))
    }

    @Test("This-Category scope with nil selection imposes no category constraint")
    func thisCategoryNilSelection() {
        #expect(ArticleSearchMatcher.matches(subject(category: "ai"), query: "", scope: .thisCategory, selectedCategory: nil))
    }

    // MARK: - Scope rawValue stability

    @Test("Scope rawValues are stable")
    func scopeRawValues() {
        #expect(ArticleSearchScope.all.rawValue == "all")
        #expect(ArticleSearchScope.unread.rawValue == "unread")
        #expect(ArticleSearchScope.thisCategory.rawValue == "thisCategory")
        #expect(ArticleSearchScope.allCases.count == 3)
    }

    // MARK: - Recent searches store

    @Test("RecentSearchesStore promotes, de-duplicates and bounds")
    func recentSearches() {
        var recents: [String] = []
        recents = RecentSearchesStore.adding("swift", to: recents)
        recents = RecentSearchesStore.adding("ai", to: recents)
        recents = RecentSearchesStore.adding("Swift", to: recents)  // case-insensitive dup → promote
        #expect(recents.first == "Swift")
        #expect(recents.count == 2)

        // Empty/whitespace terms are ignored.
        let unchanged = RecentSearchesStore.adding("   ", to: recents)
        #expect(unchanged == recents)
    }

    @Test("RecentSearchesStore caps at maxCount")
    func recentSearchesCap() {
        var recents: [String] = []
        for i in 0..<20 { recents = RecentSearchesStore.adding("term\(i)", to: recents) }
        #expect(recents.count == RecentSearchesStore.maxCount)
        #expect(recents.first == "term19")
    }

    @Test("RecentSearchesStore JSON round-trips and guards garbage")
    func recentSearchesJSON() {
        let terms = ["swift", "ai", "lego"]
        let json = RecentSearchesStore.encode(terms)
        #expect(RecentSearchesStore.decode(json) == terms)
        #expect(RecentSearchesStore.decode("not json") == [])
    }
}
