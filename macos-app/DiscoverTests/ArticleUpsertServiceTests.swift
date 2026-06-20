import Testing
import Foundation
import SwiftData

@testable import Discover

@Suite("Discover — ArticleUpsertService")
@MainActor
struct ArticleUpsertServiceTests {

    /// Builds an in-memory container over the full current schema.
    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: DiscoverCurrentSchema.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private func sampleItem(link: String, guid: String, title: String = "Title") -> ParsedItem {
        var item = ParsedItem()
        item.link = link
        item.guid = guid
        item.title = title
        item.description = "A description."
        item.feedUrl = "https://example.com/feed"
        item.category = "tech"
        item.feedName = "Example"
        item.pubDate = Date(timeIntervalSince1970: 1_700_000_000)
        return item
    }

    @Test("Inserts new articles and reports the count")
    func insertsNew() throws {
        let context = try makeContext()
        let items = [
            sampleItem(link: "https://example.com/a", guid: "a"),
            sampleItem(link: "https://example.com/b", guid: "b"),
        ]
        let count = try ArticleUpsertService.upsert(items, into: context)
        #expect(count == 2)

        let stored = try context.fetch(FetchDescriptor<ArticleModel>())
        #expect(stored.count == 2)
    }

    @Test("Double upsert of the same items inserts no duplicates")
    func noDuplicatesOnDoubleUpsert() throws {
        let context = try makeContext()
        let items = [
            sampleItem(link: "https://example.com/a", guid: "a"),
            sampleItem(link: "https://example.com/b", guid: "b"),
        ]
        let first = try ArticleUpsertService.upsert(items, into: context)
        #expect(first == 2)

        let second = try ArticleUpsertService.upsert(items, into: context)
        #expect(second == 0)

        let stored = try context.fetch(FetchDescriptor<ArticleModel>())
        #expect(stored.count == 2)
    }

    @Test("In-batch duplicate IDs collapse to one insert")
    func inBatchDedup() throws {
        let context = try makeContext()
        // Same link + guid → same ID twice in one batch.
        let items = [
            sampleItem(link: "https://example.com/a", guid: "a"),
            sampleItem(link: "https://example.com/a", guid: "a"),
        ]
        let count = try ArticleUpsertService.upsert(items, into: context)
        #expect(count == 1)
    }

    @Test("Stored ID matches the IDGenerator djb2 scheme")
    func idMatchesGenerator() throws {
        let context = try makeContext()
        let rawLink = "https://example.com/a?utm_source=x"
        let item = sampleItem(link: rawLink, guid: "a")
        _ = try ArticleUpsertService.upsert([item], into: context)

        let normLink = URLNormaliser.normalise(rawLink)
        let expectedID = IDGenerator.generate(feedUrl: normLink, guid: "a")

        let stored = try context.fetch(FetchDescriptor<ArticleModel>())
        #expect(stored.count == 1)
        #expect(stored.first?.id == expectedID)
        // The stored link is normalised (tracking param stripped).
        #expect(stored.first?.link == normLink)
    }

    @Test("Items with empty links are skipped")
    func skipsEmptyLink() throws {
        let context = try makeContext()
        var bad = sampleItem(link: "", guid: "x")
        bad.link = ""
        let count = try ArticleUpsertService.upsert([bad], into: context)
        #expect(count == 0)
    }
}
