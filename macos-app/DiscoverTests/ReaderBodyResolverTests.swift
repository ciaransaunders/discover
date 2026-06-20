import Testing
import Foundation

@testable import Discover

@Suite("Discover — ReaderBodyResolver")
@MainActor
struct ReaderBodyResolverTests {

    @Test("Prefers content when present")
    func prefersContent() {
        let body = ReaderBodyResolver.resolve(content: "<p>Full body</p>", snippet: "A snippet")
        #expect(body == .content("<p>Full body</p>"))
    }

    @Test("Falls back to snippet when content is nil")
    func snippetWhenContentNil() {
        let body = ReaderBodyResolver.resolve(content: nil, snippet: "A snippet")
        #expect(body == .snippet("A snippet"))
    }

    @Test("Falls back to snippet when content is whitespace-only")
    func snippetWhenContentBlank() {
        let body = ReaderBodyResolver.resolve(content: "   \n  ", snippet: "A snippet")
        #expect(body == .snippet("A snippet"))
    }

    @Test("Empty when both content and snippet are absent")
    func emptyWhenBothAbsent() {
        let body = ReaderBodyResolver.resolve(content: nil, snippet: "")
        #expect(body == .empty)
    }

    @Test("Empty when both are whitespace-only")
    func emptyWhenBothBlank() {
        let body = ReaderBodyResolver.resolve(content: "  ", snippet: "  ")
        #expect(body == .empty)
    }

    @Test("View model maps content to stripped paragraphs")
    func viewModelParagraphsFromContent() {
        let article = ArticleModel(
            id: "x",
            title: "T",
            snippet: "snip",
            link: "https://example.com/x",
            source: "Example",
            category: "tech",
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            content: "<p>First.</p><p>Second.</p>"
        )
        let vm = ReaderViewModel(article: article)
        #expect(vm.hasBody)
        #expect(vm.paragraphs == ["First.", "Second."])
    }

    @Test("View model uses snippet as a single paragraph when no content")
    func viewModelSnippetParagraph() {
        let article = ArticleModel(
            id: "y",
            title: "T",
            snippet: "Just a snippet.",
            link: "https://example.com/y",
            source: "Example",
            category: "tech",
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            content: nil
        )
        let vm = ReaderViewModel(article: article)
        #expect(vm.paragraphs == ["Just a snippet."])
    }

    @Test("View model reports no body when both are empty")
    func viewModelEmpty() {
        let article = ArticleModel(
            id: "z",
            title: "T",
            snippet: "",
            link: "https://example.com/z",
            source: "Example",
            category: "tech",
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            content: nil
        )
        let vm = ReaderViewModel(article: article)
        #expect(!vm.hasBody)
        #expect(vm.paragraphs.isEmpty)
    }
}
