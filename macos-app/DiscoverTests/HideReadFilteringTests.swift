import Testing
import Foundation

@testable import Discover

@Suite("Discover — Hide Read Filtering")
struct HideReadFilteringTests {

    private func subject(_ isRead: Bool) -> ArticleVisibilitySubject {
        ArticleVisibilitySubject(isRead: isRead)
    }

    // MARK: - visible(_:hideRead:)

    @Test("Keeps all when hideRead is off")
    func keepsAllWhenOff() {
        let subjects = [subject(false), subject(true), subject(false)]
        let result = ArticleVisibilityFilter.visible(subjects, hideRead: false)
        #expect(result.count == 3)
    }

    @Test("Drops read articles when hideRead is on")
    func dropsReadWhenOn() {
        let subjects = [subject(false), subject(true), subject(false), subject(true)]
        let result = ArticleVisibilityFilter.visible(subjects, hideRead: true)
        let noneRead = result.allSatisfy { !$0.isRead }
        #expect(result.count == 2)
        #expect(noneRead)
    }

    @Test("Returns empty when every article is read and hideRead is on")
    func emptyWhenAllRead() {
        let subjects = [subject(true), subject(true)]
        let result = ArticleVisibilityFilter.visible(subjects, hideRead: true)
        #expect(result.isEmpty)
    }

    @Test("Preserves order")
    func preservesOrder() {
        // Tag identity via a parallel array of indices through the generic projection variant.
        struct Item { let idx: Int; let isRead: Bool }
        let items = [
            Item(idx: 0, isRead: false),
            Item(idx: 1, isRead: true),
            Item(idx: 2, isRead: false),
            Item(idx: 3, isRead: false),
        ]
        let result = ArticleVisibilityFilter.visible(items, hideRead: true) { $0.isRead }
        #expect(result.map(\.idx) == [0, 2, 3])
    }

    // MARK: - compose with search

    @Test("Composes with an upstream search filter (filter then hide-read)")
    func composesWithSearch() {
        // Simulate the search stage having already narrowed to 3 articles, 2 of them read.
        let searchResult = [subject(false), subject(true), subject(true)]
        let composed = ArticleVisibilityFilter.visible(searchResult, hideRead: true)
        let noneRead = composed.allSatisfy { !$0.isRead }
        #expect(composed.count == 1)
        #expect(noneRead)
    }

    // MARK: - feedURLsWithUnread / feedHasUnread

    @Test("feedURLsWithUnread collects only feeds with at least one unread article")
    func feedURLsWithUnread() {
        let pairs: [(feedUrl: String?, isRead: Bool)] = [
            (feedUrl: "https://a.com/feed", isRead: false),
            (feedUrl: "https://a.com/feed", isRead: true),
            (feedUrl: "https://b.com/feed", isRead: true),
            (feedUrl: "https://c.com/feed", isRead: false),
            (feedUrl: nil, isRead: false),
            (feedUrl: "", isRead: false),
        ]
        let set = ArticleVisibilityFilter.feedURLsWithUnread(pairs)
        #expect(set == ["https://a.com/feed", "https://c.com/feed"])
    }

    @Test("feedHasUnread reflects membership of the unread set")
    func feedHasUnread() {
        let set: Set<String> = ["https://a.com/feed"]
        #expect(ArticleVisibilityFilter.feedHasUnread("https://a.com/feed", in: set))
        #expect(!ArticleVisibilityFilter.feedHasUnread("https://b.com/feed", in: set))
    }

    @Test("A feed with every article read is absent from the unread set")
    func allReadFeedAbsent() {
        let pairs: [(feedUrl: String?, isRead: Bool)] = [
            (feedUrl: "https://read-only.com/feed", isRead: true),
            (feedUrl: "https://read-only.com/feed", isRead: true),
        ]
        let set = ArticleVisibilityFilter.feedURLsWithUnread(pairs)
        #expect(!ArticleVisibilityFilter.feedHasUnread("https://read-only.com/feed", in: set))
    }
}
