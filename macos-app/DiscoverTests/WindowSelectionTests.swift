import Testing
import Foundation

@testable import Discover

/// Cluster F2 — `SidebarSelection` is the multi-window payload (`WindowGroup(for:)`). These tests
/// cover the window-restoration contract: lossless Codable round-trip (incl. `.folder`), Hashable
/// identity, and the "restored category/folder no longer exists → falls back to `.all`" resolver.
@Suite("Discover — Window selection (multi-window payload)")
struct WindowSelectionTests {

    private static let cases: [SidebarSelection] = [
        .all,
        .allUnread,
        .today,
        .starred,
        .category("ai"),
        .folder(slug: "morning-reads", feedUrls: ["https://a.com/feed", "https://b.com/rss"]),
        .folder(slug: "empty", feedUrls: []),
    ]

    // MARK: - Codable round-trip (window state restoration)

    @Test("Codable round-trips losslessly for every case incl. .folder payload")
    func codableRoundTrip() throws {
        for selection in Self.cases {
            let data = try JSONEncoder().encode(selection)
            let restored = try JSONDecoder().decode(SidebarSelection.self, from: data)
            #expect(restored == selection, "round-trip failed for \(selection)")
        }
    }

    @Test(".folder carries its feed URLs through Codable")
    func folderPayloadSurvives() throws {
        let selection = SidebarSelection.folder(slug: "f", feedUrls: ["u1", "u2", "u3"])
        let data = try JSONEncoder().encode(selection)
        let restored = try JSONDecoder().decode(SidebarSelection.self, from: data)
        guard case .folder(let slug, let urls) = restored else {
            Issue.record("expected .folder, got \(restored)")
            return
        }
        #expect(slug == "f")
        #expect(urls == ["u1", "u2", "u3"])
    }

    // MARK: - Hashable / Equatable

    @Test("Hashable: equal cases share a hash, distinct cases differ")
    func hashable() {
        #expect(SidebarSelection.all == SidebarSelection.all)
        #expect(SidebarSelection.category("ai") != SidebarSelection.category("tech"))
        #expect(SidebarSelection.all != SidebarSelection.allUnread)

        let set: Set<SidebarSelection> = [.all, .all, .category("ai"), .category("ai"), .today]
        #expect(set.count == 3)
    }

    @Test("folders with different feed URLs are still distinct values")
    func folderValueIdentity() {
        let a = SidebarSelection.folder(slug: "f", feedUrls: ["x"])
        let b = SidebarSelection.folder(slug: "f", feedUrls: ["y"])
        #expect(a != b)
    }

    // MARK: - Restored-but-deleted resolution (cluster F2)

    @Test("a restored category that still exists is kept")
    func keepsExistingCategory() {
        let selection = SidebarSelection.category("ai")
        let resolved = selection.resolved(
            availableCategorySlugs: ["ai", "tech"],
            availableFolderSlugs: []
        )
        #expect(resolved == .category("ai"))
    }

    @Test("a restored category that no longer exists falls back to .all")
    func deletedCategoryFallsBack() {
        let selection = SidebarSelection.category("gone")
        let resolved = selection.resolved(
            availableCategorySlugs: ["ai", "tech"],
            availableFolderSlugs: []
        )
        #expect(resolved == .all)
    }

    @Test("a restored folder that no longer exists falls back to .all")
    func deletedFolderFallsBack() {
        let selection = SidebarSelection.folder(slug: "gone", feedUrls: ["u"])
        let resolved = selection.resolved(
            availableCategorySlugs: [],
            availableFolderSlugs: ["keep"]
        )
        #expect(resolved == .all)
    }

    @Test("an existing folder is kept (matched by slug)")
    func keepsExistingFolder() {
        let selection = SidebarSelection.folder(slug: "keep", feedUrls: ["u"])
        let resolved = selection.resolved(
            availableCategorySlugs: [],
            availableFolderSlugs: ["keep"]
        )
        #expect(resolved == selection)
    }

    @Test("smart feeds and .all always resolve to themselves")
    func smartFeedsUnaffected() {
        for selection in [SidebarSelection.all, .allUnread, .today, .starred] {
            let resolved = selection.resolved(availableCategorySlugs: [], availableFolderSlugs: [])
            #expect(resolved == selection)
        }
    }
}
