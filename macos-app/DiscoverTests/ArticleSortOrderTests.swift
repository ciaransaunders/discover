import Testing
import Foundation

@testable import Discover

@Suite("Discover — ArticleSortOrder")
struct ArticleSortOrderTests {

    // MARK: - Fixtures

    private func makeArticle(
        id: String,
        source: String,
        published: TimeInterval
    ) -> ArticleModel {
        ArticleModel(
            id: id,
            title: "Title \(id)",
            snippet: "snippet",
            link: "https://example.com/\(id)",
            source: source,
            category: "tech",
            publishedAt: Date(timeIntervalSince1970: published),
            feedUrl: "https://example.com/feed"
        )
    }

    // MARK: - Raw-value stability (persisted in @AppStorage — must not change)

    @Test("rawValues are stable identifiers")
    func rawValueStability() {
        #expect(ArticleSortOrder.dateDescending.rawValue == "dateDescending")
        #expect(ArticleSortOrder.dateAscending.rawValue == "dateAscending")
        #expect(ArticleSortOrder.sourceAscending.rawValue == "sourceAscending")
    }

    @Test("rawValue round-trips for every case")
    func rawValueRoundTrip() {
        for order in ArticleSortOrder.allCases {
            #expect(ArticleSortOrder(rawValue: order.rawValue) == order)
        }
    }

    @Test("default is newest-first (matches the @Query sort)")
    func defaultIsDateDescending() {
        #expect(ArticleSortOrder.default == .dateDescending)
    }

    @Test("unknown rawValue is rejected")
    func rejectsUnknown() {
        #expect(ArticleSortOrder(rawValue: "bogus") == nil)
    }

    // MARK: - Comparator correctness

    @Test("dateDescending sorts newest first")
    func dateDescending() {
        let a = makeArticle(id: "a", source: "Zeta", published: 100)
        let b = makeArticle(id: "b", source: "Alpha", published: 300)
        let c = makeArticle(id: "c", source: "Mid", published: 200)
        let sorted = ArticleSortOrder.dateDescending.sorted([a, b, c])
        #expect(sorted.map(\.id) == ["b", "c", "a"])
    }

    @Test("dateAscending sorts oldest first")
    func dateAscending() {
        let a = makeArticle(id: "a", source: "Zeta", published: 100)
        let b = makeArticle(id: "b", source: "Alpha", published: 300)
        let c = makeArticle(id: "c", source: "Mid", published: 200)
        let sorted = ArticleSortOrder.dateAscending.sorted([a, b, c])
        #expect(sorted.map(\.id) == ["a", "c", "b"])
    }

    @Test("sourceAscending sorts A→Z, newest first within a source")
    func sourceAscending() {
        let z = makeArticle(id: "z", source: "Zeta", published: 100)
        let a1 = makeArticle(id: "a1", source: "Alpha", published: 100)
        let a2 = makeArticle(id: "a2", source: "Alpha", published: 300)
        let m = makeArticle(id: "m", source: "Mid", published: 200)
        let sorted = ArticleSortOrder.sourceAscending.sorted([z, a1, a2, m])
        // Alpha (newest a2 then a1), then Mid, then Zeta.
        #expect(sorted.map(\.id) == ["a2", "a1", "m", "z"])
    }

    @Test("sourceAscending is case-insensitive")
    func sourceAscendingCaseInsensitive() {
        let lower = makeArticle(id: "lower", source: "apple", published: 100)
        let upper = makeArticle(id: "upper", source: "Banana", published: 100)
        let sorted = ArticleSortOrder.sourceAscending.sorted([upper, lower])
        #expect(sorted.map(\.id) == ["lower", "upper"])
    }

    // MARK: - Stable / total ordering (ties never reorder non-deterministically)

    @Test("equal dates fall back to stable id ordering")
    func stableTieBreak() {
        let a = makeArticle(id: "aaa", source: "Same", published: 100)
        let b = makeArticle(id: "bbb", source: "Same", published: 100)
        // Same source & date → id ascending tiebreak, regardless of input order.
        #expect(ArticleSortOrder.dateDescending.sorted([b, a]).map(\.id) == ["aaa", "bbb"])
        #expect(ArticleSortOrder.dateDescending.sorted([a, b]).map(\.id) == ["aaa", "bbb"])
    }

    @Test("empty and single-element inputs are returned unchanged")
    func degenerateInputs() {
        #expect(ArticleSortOrder.sourceAscending.sorted([]).isEmpty)
        let only = makeArticle(id: "x", source: "S", published: 1)
        #expect(ArticleSortOrder.dateAscending.sorted([only]).map(\.id) == ["x"])
    }

    // MARK: - Hero respects the chosen sort

    @Test("the hero (first element) reflects the chosen sort order")
    func heroRespectsSort() {
        let old = makeArticle(id: "old", source: "Beta", published: 100)
        let new = makeArticle(id: "new", source: "Alpha", published: 999)
        let input = [old, new]

        #expect(ArticleSortOrder.dateDescending.sorted(input).first?.id == "new")
        #expect(ArticleSortOrder.dateAscending.sorted(input).first?.id == "old")
        // Source A–Z: "Alpha" (new) before "Beta" (old).
        #expect(ArticleSortOrder.sourceAscending.sorted(input).first?.id == "new")
    }
}
