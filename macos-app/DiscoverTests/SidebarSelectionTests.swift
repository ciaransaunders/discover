import Testing
import Foundation

@testable import Discover

@Suite("Discover — SidebarSelection round-trip")
struct SidebarSelectionTests {

    private static let cases: [SidebarSelection] = [
        .all,
        .allUnread,
        .today,
        .starred,
        .category("ai"),
        .folder(slug: "morning-reads", feedUrls: ["https://a.com/feed", "https://b.com/rss"]),
    ]

    @Test("rawValue round-trips losslessly for every case")
    func rawValueRoundTrip() {
        for selection in Self.cases {
            let restored = SidebarSelection(rawValue: selection.rawValue)
            #expect(restored == selection, "round-trip failed for \(selection)")
        }
    }

    @Test("Codable round-trips losslessly for every case")
    func codableRoundTrip() throws {
        for selection in Self.cases {
            let data = try JSONEncoder().encode(selection)
            let restored = try JSONDecoder().decode(SidebarSelection.self, from: data)
            #expect(restored == selection)
        }
    }

    @Test("init(rawValue:) returns nil for garbage input")
    func rejectsGarbage() {
        #expect(SidebarSelection(rawValue: "not json at all") == nil)
    }

    @Test("smart-feed flag is set only for synthetic rows")
    func smartFeedFlag() {
        #expect(SidebarSelection.allUnread.isSmartFeed)
        #expect(SidebarSelection.today.isSmartFeed)
        #expect(SidebarSelection.starred.isSmartFeed)
        #expect(!SidebarSelection.all.isSmartFeed)
        #expect(!SidebarSelection.category("ai").isSmartFeed)
        #expect(!SidebarSelection.folder(slug: "f", feedUrls: []).isSmartFeed)
    }

    @Test("titles are stable for smart feeds")
    func titles() {
        #expect(SidebarSelection.all.title == "All News")
        #expect(SidebarSelection.allUnread.title == "All Unread")
        #expect(SidebarSelection.today.title == "Today")
        #expect(SidebarSelection.starred.title == "Starred")
    }
}
