import Testing
import Foundation

@testable import Discover

@Suite("Discover — Feed Search Matcher")
struct FeedSearchTests {

    private func subject(
        name: String = "The Verge AI",
        url: String = "https://theverge.com/ai/rss",
        category: String = "ai"
    ) -> FeedSearchSubject {
        FeedSearchSubject(name: name, url: url, category: category)
    }

    @Test("Empty query matches everything")
    func emptyMatchesAll() {
        #expect(FeedSearchMatcher.matches(subject(), query: ""))
        #expect(FeedSearchMatcher.matches(subject(), query: "   "))
    }

    @Test("Case-insensitive name match")
    func nameMatch() {
        #expect(FeedSearchMatcher.matches(subject(), query: "verge"))
        #expect(FeedSearchMatcher.matches(subject(), query: "VERGE"))
    }

    @Test("Case-insensitive URL match")
    func urlMatch() {
        #expect(FeedSearchMatcher.matches(subject(), query: "theverge.com"))
    }

    @Test("Case-insensitive category match")
    func categoryMatch() {
        #expect(FeedSearchMatcher.matches(subject(), query: "ai"))
    }

    @Test("No match returns false")
    func noMatch() {
        #expect(!FeedSearchMatcher.matches(subject(), query: "gaming"))
    }
}
