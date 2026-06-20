import Testing
import Foundation

@testable import Discover

private final class BundleToken {}

@Suite("Discover — Feed Discovery (extractFeedLinks)")
struct FeedDiscoveryTests {

    private static let base = URL(string: "https://example.com/blog/")!

    @Test("Finds an absolute RSS feed link")
    func absoluteRSS() {
        let html = #"<link rel="alternate" type="application/rss+xml" href="https://example.com/feed.xml">"#
        let links = FeedDiscoveryActor.extractFeedLinks(fromHTML: html, baseURL: Self.base)
        #expect(links.contains("https://example.com/feed.xml"))
    }

    @Test("Finds an Atom feed link (type attribute)")
    func atom() {
        let html = #"<link href="https://example.com/atom.xml" type="application/atom+xml" rel="alternate">"#
        let links = FeedDiscoveryActor.extractFeedLinks(fromHTML: html, baseURL: Self.base)
        #expect(links.contains("https://example.com/atom.xml"))
    }

    @Test("Resolves a relative href against the base URL")
    func relativeHref() {
        let html = #"<link rel="alternate" type="application/rss+xml" href="/feed.xml">"#
        let links = FeedDiscoveryActor.extractFeedLinks(fromHTML: html, baseURL: Self.base)
        #expect(links.contains("https://example.com/feed.xml"))
    }

    @Test("Resolves a protocol-relative href")
    func protocolRelative() {
        let html = #"<link rel="alternate" type="application/rss+xml" href="//cdn.example.com/rss">"#
        let links = FeedDiscoveryActor.extractFeedLinks(fromHTML: html, baseURL: Self.base)
        #expect(links.contains("https://cdn.example.com/rss"))
    }

    @Test("Returns empty when no feed links are present")
    func none() {
        let html = "<html><head><title>No feeds here</title></head><body></body></html>"
        let links = FeedDiscoveryActor.extractFeedLinks(fromHTML: html, baseURL: Self.base)
        #expect(links.isEmpty)
    }

    @Test("Ignores non-feed alternate links (e.g. stylesheet)")
    func ignoresStylesheet() {
        let html = #"<link rel="stylesheet" href="/styles/main.css">"#
        let links = FeedDiscoveryActor.extractFeedLinks(fromHTML: html, baseURL: Self.base)
        #expect(links.isEmpty)
    }

    @Test("Parses all feed links from the fixture, resolving relative + protocol-relative")
    func fixture() throws {
        let bundle = Bundle(for: BundleToken.self)
        let url = try #require(bundle.url(forResource: "html_with_feed_link", withExtension: "html"))
        let html = try String(contentsOf: url, encoding: .utf8)
        let links = FeedDiscoveryActor.extractFeedLinks(fromHTML: html, baseURL: URL(string: "https://example.com/")!)

        #expect(links.contains("https://example.com/feed.xml"))
        #expect(links.contains("https://example.com/atom.xml"))
        #expect(links.contains("https://cdn.example.com/comments/rss"))
        // The stylesheet link must NOT be included.
        #expect(!links.contains(where: { $0.hasSuffix("main.css") }))
    }

    @Test("normaliseInput adds https:// when scheme is missing")
    func normaliseInput() {
        #expect(FeedDiscoveryActor.normaliseInput("example.com") == "https://example.com")
        #expect(FeedDiscoveryActor.normaliseInput("https://example.com") == "https://example.com")
        #expect(FeedDiscoveryActor.normaliseInput("http://example.com") == "http://example.com")
        #expect(FeedDiscoveryActor.normaliseInput("feed://example.com/rss") == "https://example.com/rss")
        #expect(FeedDiscoveryActor.normaliseInput("  example.com  ") == "https://example.com")
    }

    @Test("Infers feed title from RSS fixture data")
    func feedTitleFromFixture() throws {
        let bundle = Bundle(for: BundleToken.self)
        let url = try #require(bundle.url(forResource: "rss_sample", withExtension: "xml"))
        let data = try Data(contentsOf: url)
        let title = RSSParser.feedTitle(data: data)
        #expect(title != nil)
        #expect(!(title ?? "").isEmpty)
    }
}
