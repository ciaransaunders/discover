import Testing
import Foundation
import SwiftData

@testable import Discover

@Suite("Discover — Starred Articles")
@MainActor
struct StarredArticlesTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: DiscoverCurrentSchema.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private func makeArticle(
        id: String,
        title: String = "Title",
        isStarred: Bool = false
    ) -> ArticleModel {
        ArticleModel(
            id: id,
            title: title,
            snippet: "snippet",
            link: "https://example.com/\(id)",
            source: "Example",
            category: "tech",
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            feedUrl: "https://example.com/feed",
            isStarred: isStarred
        )
    }

    @Test("isStarred defaults to false")
    func defaultUnstarred() throws {
        let context = try makeContext()
        let article = makeArticle(id: "a")
        context.insert(article)
        try context.save()

        let stored = try context.fetch(FetchDescriptor<ArticleModel>())
        #expect(stored.count == 1)
        #expect(stored.first?.isStarred == false)
    }

    @Test("Toggling isStarred persists")
    func togglePersists() throws {
        let context = try makeContext()
        let article = makeArticle(id: "a")
        context.insert(article)
        try context.save()

        article.isStarred = true
        try context.save()

        let stored = try context.fetch(FetchDescriptor<ArticleModel>())
        #expect(stored.first?.isStarred == true)
    }

    @Test("Starred predicate returns only starred articles")
    func starredPredicateOnlyStarred() throws {
        let context = try makeContext()
        context.insert(makeArticle(id: "a", isStarred: true))
        context.insert(makeArticle(id: "b", isStarred: false))
        context.insert(makeArticle(id: "c", isStarred: true))
        try context.save()

        let descriptor = FetchDescriptor<ArticleModel>(predicate: SmartFeedPredicates.starred())
        let starred = try context.fetch(descriptor)
        let allStarred = starred.allSatisfy(\.isStarred)
        #expect(starred.count == 2)
        #expect(allStarred)
        #expect(Set(starred.map(\.id)) == ["a", "c"])
    }
}
