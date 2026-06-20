import Testing
import Foundation

@testable import Discover

private final class BundleToken {}

private enum FixtureError: Error, CustomStringConvertible {
  case missingResource(String)
  var description: String {
    switch self {
    case .missingResource(let name): return "Missing test fixture resource: \(name)"
    }
  }
}

/// Loads a bundled XML fixture from the test target's resources.
private func loadFixture(named name: String, ext: String) throws -> Data {
  let bundle = Bundle(for: BundleToken.self)
  guard let url = bundle.url(forResource: name, withExtension: ext) else {
    throw FixtureError.missingResource("\(name).\(ext)")
  }
  return try Data(contentsOf: url)
}

/// Phase 1 smoke tests — verify seed data integrity before any networking is wired up.
@Suite("Discover — Phase 1 Smoke Tests")
struct DiscoverTests {

  @Test("DefaultFeeds contains exactly 13 categories")
  func defaultCategoryCount() {
    #expect(DefaultFeeds.categories.count == 13)
  }

  @Test("DefaultFeeds contains at least 40 feeds")
  func defaultFeedMinimumFeedCount() {
    #expect(DefaultFeeds.feeds.count >= 40)
  }

  @Test("Every feed's category slug matches a known category")
  func feedCategorySlugValidity() {
    let validSlugs = Set(DefaultFeeds.categories.map(\.slug))
    for feed in DefaultFeeds.feeds {
      #expect(
        validSlugs.contains(feed.category),
        "Feed '\(feed.name)' references unknown category '\(feed.category)'"
      )
    }
  }

  @Test("Feed URLs are unique (no duplicates)")
  func feedUrlsAreUnique() {
    let urls = DefaultFeeds.feeds.map(\.url)
    #expect(urls.count == Set(urls).count)
  }

  @Test("Category slugs are unique")
  func categorySlugsAreUnique() {
    let slugs = DefaultFeeds.categories.map(\.slug)
    #expect(slugs.count == Set(slugs).count)
  }

  @Test("All category colour strings are non-empty")
  func categoryColorsAreNonEmpty() {
    for cat in DefaultFeeds.categories {
      #expect(!cat.color.isEmpty, "Category '\(cat.slug)' has an empty colour string")
    }
  }

  @Test("All feed URLs are non-empty strings")
  func feedUrlsAreNonEmpty() {
    for feed in DefaultFeeds.feeds {
      #expect(!feed.url.isEmpty, "Feed '\(feed.name)' has an empty URL")
    }
  }
}

@Suite("Discover — RSSParser Fixture Tests")
struct RSSParserFixtureTests {

  @Test("Parses RSS 2.0 fixtures (items, GUID, date, description)")
  func parsesRSS() throws {
    let data = try loadFixture(named: "rss_sample", ext: "xml")
    let items = RSSParser.parse(
      data: data,
      feedUrl: "https://example.com/rss",
      feedName: "Example RSS",
      category: "tech"
    )

    #expect(items.count == 2)

    let first = items[0]
    #expect(first.guid == "guid-1")
    #expect(first.link == "https://example.com/articles/1?utm_source=test")
    #expect(first.pubDate != nil)
    #expect(first.description.contains("<p>"))
    #expect(first.mediaUrl == "https://cdn.example.com/img/hero1.jpg")
    #expect(first.mediaType == "image/jpeg")

    let second = items[1]
    #expect(second.guid == "guid-2")
    #expect(second.link == "https://example.com/articles/2")
    #expect(second.enclosureUrl == "https://cdn.example.com/img/enclosure2.png")
    #expect(second.enclosureType == "image/png")
  }

  @Test("Parses Atom fixtures (alternate link, updated/published, content)")
  func parsesAtom() throws {
    let data = try loadFixture(named: "atom_sample", ext: "xml")
    let items = RSSParser.parse(
      data: data,
      feedUrl: "https://example.com/atom",
      feedName: "Example Atom",
      category: "ai"
    )

    #expect(items.count == 2)

    let first = items[0]
    #expect(first.link == "https://example.com/atom/1")
    #expect(first.guid == "tag:example.com,2026:1")
    #expect(first.pubDate != nil)
    #expect(!first.content.isEmpty)

    let second = items[1]
    #expect(second.link == "https://example.com/atom/2")
    #expect(second.guid == "tag:example.com,2026:2")
    #expect(second.pubDate != nil)
  }
}

@Suite("Discover — Utility Tests")
struct UtilityTests {
  @Test("HTMLStripper removes tags and decodes entities")
  func testHTMLStripper() {
    let input = "<p>Hello &amp; <b>World</b>!</p>"
    let result = HTMLStripper.strip(input)
    #expect(result == "Hello & World!")
  }

  @Test("Parses RSS with namespaces (content:encoded, media:thumbnail)")
  func parsesRSSNamespaces() throws {
    let data = try loadFixture(named: "namespaces_sample", ext: "xml")
    let items = RSSParser.parse(
      data: data,
      feedUrl: "https://example.com/ns",
      feedName: "Namespace Test",
      category: "tech"
    )

    #expect(items.count == 1)
    let item = items[0]
    #expect(item.guid == "encoded-1")
    #expect(item.title == "Article with Encoded Content")
    #expect(item.description == "Short summary.")
    #expect(item.content.contains("full <b>encoded</b> content"))
    #expect(item.thumbnail == "https://example.com/thumb.jpg")
  }

  @Test("Parses YouTube Atom fixtures (media:group, media:thumbnail)")
  func parsesYouTubeAtom() throws {
    let data = try loadFixture(named: "youtube_sample", ext: "xml")
    let items = RSSParser.parse(
      data: data,
      feedUrl: "https://example.com/youtube",
      feedName: "YouTube Test",
      category: "video"
    )

    #expect(items.count == 1)
    let item = items[0]
    #expect(item.guid == "yt:video:abc12345")
    #expect(item.title == "Awesome Filmmaking Tutorial")
    #expect(item.link == "https://www.youtube.com/watch?v=abc12345")
    #expect(item.thumbnail == "https://i.ytimg.com/vi/abc12345/hqdefault.jpg")
  }
}

