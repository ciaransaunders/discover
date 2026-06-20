#if os(macOS)
import Testing
import Foundation
import SwiftData

@testable import Discover

/// Cluster F3 — the AppleScript read-only counts (`unread count` / `article count`) must return the
/// right numbers and must perform NO writes against the shared store.
@Suite("Discover — ScriptingDataReader (read-only counts)")
@MainActor
struct ScriptingDataReaderTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: DiscoverCurrentSchema.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makeArticle(id: String, isRead: Bool) -> ArticleModel {
        ArticleModel(
            id: id,
            title: "T\(id)",
            snippet: "s",
            link: "https://example.com/\(id)",
            source: "Source",
            category: "tech",
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            isRead: isRead,
            feedUrl: "https://example.com/feed"
        )
    }

    @Test("articleCount returns the total number of articles")
    func articleCount() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        context.insert(makeArticle(id: "a", isRead: false))
        context.insert(makeArticle(id: "b", isRead: true))
        context.insert(makeArticle(id: "c", isRead: false))
        try context.save()

        #expect(ScriptingDataReader.articleCount(container: container) == 3)
    }

    @Test("unreadCount returns only the unread articles")
    func unreadCount() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        context.insert(makeArticle(id: "a", isRead: false))
        context.insert(makeArticle(id: "b", isRead: true))
        context.insert(makeArticle(id: "c", isRead: false))
        try context.save()

        #expect(ScriptingDataReader.unreadCount(container: container) == 2)
    }

    @Test("counts are zero on an empty store")
    func emptyStore() throws {
        let container = try makeContainer()
        #expect(ScriptingDataReader.articleCount(container: container) == 0)
        #expect(ScriptingDataReader.unreadCount(container: container) == 0)
    }

    @Test("counts are zero (not a crash) when the container is nil")
    func nilContainer() {
        #expect(ScriptingDataReader.articleCount(container: nil) == 0)
        #expect(ScriptingDataReader.unreadCount(container: nil) == 0)
    }

    @Test("reading performs NO writes (counts do not change the store)")
    func readsAreSideEffectFree() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        context.insert(makeArticle(id: "a", isRead: false))
        context.insert(makeArticle(id: "b", isRead: true))
        try context.save()

        // Snapshot read-state before any scripting reads.
        let before = try context.fetch(FetchDescriptor<ArticleModel>())
            .map { ($0.id, $0.isRead) }
            .sorted { $0.0 < $1.0 }

        // Exercise the readers repeatedly.
        for _ in 0..<5 {
            _ = ScriptingDataReader.articleCount(container: container)
            _ = ScriptingDataReader.unreadCount(container: container)
        }

        // The store must be byte-identical: same count, same ids, same read-state, no inserts.
        let after = try context.fetch(FetchDescriptor<ArticleModel>())
            .map { ($0.id, $0.isRead) }
            .sorted { $0.0 < $1.0 }

        #expect(after.count == 2)
        #expect(before.map(\.0) == after.map(\.0))
        #expect(before.map(\.1) == after.map(\.1))
        // No new context has unsaved changes left dangling from a read.
        #expect(context.hasChanges == false)
    }
}
#endif
