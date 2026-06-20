import Testing
import Foundation
import SwiftData

@testable import Discover

@Suite("Discover — Folders")
@MainActor
struct FolderTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: DiscoverCurrentSchema.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private func makeArticle(id: String, feedUrl: String?) -> ArticleModel {
        ArticleModel(
            id: id,
            title: "Title \(id)",
            snippet: "snippet",
            link: "https://example.com/\(id)",
            source: "Example",
            category: "tech",
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            feedUrl: feedUrl
        )
    }

    @Test("A new folder starts empty")
    func newFolderEmpty() throws {
        let context = try makeContext()
        let vm = FeedManagerViewModel()
        vm.newFolderName = "Morning Reads"
        vm.addFolder(context: context)

        let folders = try context.fetch(FetchDescriptor<FolderModel>())
        #expect(folders.count == 1)
        #expect(folders.first?.name == "Morning Reads")
        #expect(folders.first?.slug == "morning-reads")
        #expect(folders.first?.feedUrls.isEmpty == true)
        #expect(vm.errorMessage == nil)
    }

    @Test("Adding a feed twice does not duplicate membership")
    func addFeedNoDupes() throws {
        let context = try makeContext()
        let vm = FeedManagerViewModel()
        let folder = FolderModel(slug: "f", name: "F")
        context.insert(folder)
        try context.save()

        vm.addFeed("https://a.com/feed", to: folder, context: context)
        vm.addFeed("https://a.com/feed", to: folder, context: context)
        vm.addFeed("https://b.com/rss", to: folder, context: context)

        #expect(folder.feedUrls == ["https://a.com/feed", "https://b.com/rss"])
    }

    @Test("Removing a feed drops it from membership")
    func removeFeed() throws {
        let context = try makeContext()
        let vm = FeedManagerViewModel()
        let folder = FolderModel(slug: "f", name: "F", feedUrls: ["https://a.com/feed", "https://b.com/rss"])
        context.insert(folder)
        try context.save()

        vm.removeFeed("https://a.com/feed", from: folder, context: context)
        #expect(folder.feedUrls == ["https://b.com/rss"])
    }

    @Test("Folder slug uniqueness is enforced")
    func slugUniqueness() throws {
        let context = try makeContext()
        let vm = FeedManagerViewModel()
        vm.newFolderName = "Morning Reads"
        vm.addFolder(context: context)
        #expect(vm.errorMessage == nil)

        // Same name → same slug → rejected.
        vm.newFolderName = "morning reads"
        vm.addFolder(context: context)
        #expect(vm.errorMessage != nil)

        let folders = try context.fetch(FetchDescriptor<FolderModel>())
        #expect(folders.count == 1)
    }

    @Test("Slug derivation strips punctuation and collapses spaces")
    func slugDerivation() {
        #expect(FeedManagerViewModel.folderSlug(from: "Morning Reads") == "morning-reads")
        #expect(FeedManagerViewModel.folderSlug(from: "  AI & ML  ") == "ai-ml")
        #expect(FeedManagerViewModel.folderSlug(from: "News!!!") == "news")
        #expect(FeedManagerViewModel.folderSlug(from: "Tech 2026") == "tech-2026")
    }

    @Test("Folder membership with a dangling feed URL matches zero articles")
    func danglingFeedURLZeroArticles() throws {
        let context = try makeContext()
        context.insert(makeArticle(id: "a", feedUrl: "https://real.com/feed"))
        context.insert(makeArticle(id: "b", feedUrl: "https://real.com/feed"))
        try context.save()

        // Folder membership is resolved in memory (OQ-2 — the #Predicate form throws at fetch).
        let allowed: Set<String> = ["https://does-not-exist.com/feed"]
        let all = try context.fetch(FetchDescriptor<ArticleModel>())
        let matches = all.filter { SmartFeedPredicates.articleIsInFolder($0, feedUrls: allowed) }
        #expect(matches.isEmpty)
    }

    @Test("Folder membership matches only member-feed articles")
    func folderPredicateMatchesMembers() throws {
        let context = try makeContext()
        context.insert(makeArticle(id: "a", feedUrl: "https://a.com/feed"))
        context.insert(makeArticle(id: "b", feedUrl: "https://b.com/feed"))
        context.insert(makeArticle(id: "c", feedUrl: "https://c.com/feed"))
        context.insert(makeArticle(id: "d", feedUrl: nil))
        try context.save()

        let allowed: Set<String> = ["https://a.com/feed", "https://c.com/feed"]
        let all = try context.fetch(FetchDescriptor<ArticleModel>())
        let matches = all.filter { SmartFeedPredicates.articleIsInFolder($0, feedUrls: allowed) }
        #expect(Set(matches.map(\.id)) == ["a", "c"])
    }

    @Test("An article with a nil feed URL is never a folder member")
    func nilFeedURLNotMember() throws {
        let context = try makeContext()
        let article = makeArticle(id: "x", feedUrl: nil)
        context.insert(article)
        try context.save()
        #expect(!SmartFeedPredicates.articleIsInFolder(article, feedUrls: ["https://a.com/feed"]))
    }
}
