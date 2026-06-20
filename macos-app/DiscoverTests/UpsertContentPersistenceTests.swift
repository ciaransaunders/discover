import Testing
import Foundation
import SwiftData

@testable import Discover

@Suite("Discover — Upsert persists content")
@MainActor
struct UpsertContentPersistenceTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: DiscoverCurrentSchema.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private func item(link: String, guid: String, content: String) -> ParsedItem {
        var i = ParsedItem()
        i.link = link
        i.guid = guid
        i.title = "Title"
        i.description = "A description."
        i.content = content
        i.feedUrl = "https://example.com/feed"
        i.category = "tech"
        i.feedName = "Example"
        i.pubDate = Date(timeIntervalSince1970: 1_700_000_000)
        return i
    }

    @Test("Upsert writes ParsedItem.content into ArticleModel.content")
    func persistsContent() throws {
        let context = try makeContext()
        let html = "<p>Full body paragraph.</p>"
        _ = try ArticleUpsertService.upsert([item(link: "https://example.com/a", guid: "a", content: html)], into: context)

        let stored = try context.fetch(FetchDescriptor<ArticleModel>())
        #expect(stored.count == 1)
        #expect(stored.first?.content == html)
    }

    @Test("Empty content is stored as nil")
    func emptyContentBecomesNil() throws {
        let context = try makeContext()
        _ = try ArticleUpsertService.upsert([item(link: "https://example.com/b", guid: "b", content: "")], into: context)

        let stored = try context.fetch(FetchDescriptor<ArticleModel>())
        #expect(stored.count == 1)
        #expect(stored.first?.content == nil)
    }

    @Test("Other upsert behaviour is unchanged (dedup + count)")
    func upsertBehaviourUnchanged() throws {
        let context = try makeContext()
        let items = [
            item(link: "https://example.com/a", guid: "a", content: "<p>A</p>"),
            item(link: "https://example.com/a", guid: "a", content: "<p>A again</p>"),
        ]
        let count = try ArticleUpsertService.upsert(items, into: context)
        #expect(count == 1)
    }
}
