import Testing
import Foundation
import SwiftData

@testable import Discover

@Suite("Discover — ArticleOpener")
@MainActor
struct ArticleOpenerTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: DiscoverCurrentSchema.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private func makeArticle(id: String = "a", isRead: Bool = false) -> ArticleModel {
        ArticleModel(
            id: id,
            title: "Title",
            snippet: "snippet",
            link: "https://example.com/\(id)",
            source: "Example",
            category: "tech",
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            isRead: isRead
        )
    }

    /// A recording strategy that captures the requested open configuration instead of
    /// launching the system browser.
    @MainActor
    final class Recorder {
        var requestedURL: URL?
        var requestedBackground: Bool?
        lazy var strategy = ArticleOpener.OpenStrategy { [weak self] url, background in
            self?.requestedURL = url
            self?.requestedBackground = background
        }
    }

    @Test("Foreground open requests background == false")
    func foregroundOpen() throws {
        let context = try makeContext()
        let recorder = Recorder()
        let article = makeArticle()
        context.insert(article)

        ArticleOpener.openInBrowser(
            article,
            markRead: false,
            inBackground: false,
            context: context,
            strategy: recorder.strategy
        )

        #expect(recorder.requestedBackground == false)
        #expect(recorder.requestedURL == URL(string: "https://example.com/a"))
    }

    @Test("Background open requests background == true")
    func backgroundOpen() throws {
        let context = try makeContext()
        let recorder = Recorder()
        let article = makeArticle()
        context.insert(article)

        ArticleOpener.openInBrowser(
            article,
            markRead: false,
            inBackground: true,
            context: context,
            strategy: recorder.strategy
        )

        #expect(recorder.requestedBackground == true)
    }

    @Test("markRead marks the article read before opening")
    func marksReadOnOpen() throws {
        let context = try makeContext()
        let recorder = Recorder()
        let article = makeArticle(isRead: false)
        context.insert(article)

        ArticleOpener.openInBrowser(
            article,
            markRead: true,
            inBackground: false,
            context: context,
            strategy: recorder.strategy
        )

        #expect(article.isRead == true)
        #expect(recorder.requestedURL != nil)
    }

    @Test("markRead == false leaves read state untouched")
    func doesNotMarkRead() throws {
        let context = try makeContext()
        let recorder = Recorder()
        let article = makeArticle(isRead: false)
        context.insert(article)

        ArticleOpener.openInBrowser(
            article,
            markRead: false,
            inBackground: false,
            context: context,
            strategy: recorder.strategy
        )

        #expect(article.isRead == false)
    }

    @Test("toggleRead flips and persists the read flag")
    func toggleReadPersists() throws {
        let context = try makeContext()
        let article = makeArticle(isRead: false)
        context.insert(article)
        try context.save()

        ArticleOpener.toggleRead(article, context: context)
        #expect(article.isRead == true)

        let stored = try context.fetch(FetchDescriptor<ArticleModel>())
        #expect(stored.first?.isRead == true)
    }

    @Test("markRead is idempotent on an already-read article")
    func markReadIdempotent() throws {
        let context = try makeContext()
        let article = makeArticle(isRead: true)
        context.insert(article)

        ArticleOpener.markRead(article, context: context)
        #expect(article.isRead == true)
    }

    @Test("Invalid URL does not invoke the open strategy")
    func invalidURLNoOpen() throws {
        let context = try makeContext()
        let recorder = Recorder()
        let article = ArticleModel(
            id: "bad",
            title: "Title",
            snippet: "s",
            link: "",
            source: "Example",
            category: "tech",
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        context.insert(article)

        ArticleOpener.openInBrowser(
            article,
            markRead: false,
            inBackground: false,
            context: context,
            strategy: recorder.strategy
        )

        #expect(recorder.requestedURL == nil)
    }
}
