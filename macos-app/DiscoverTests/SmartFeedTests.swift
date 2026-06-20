import Testing
import Foundation
import SwiftData

@testable import Discover

@Suite("Discover — Smart Feeds")
@MainActor
struct SmartFeedTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: DiscoverCurrentSchema.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private func makeArticle(
        id: String,
        isRead: Bool = false,
        publishedAt: Date
    ) -> ArticleModel {
        ArticleModel(
            id: id,
            title: "Title \(id)",
            snippet: "snippet",
            link: "https://example.com/\(id)",
            source: "Example",
            category: "tech",
            publishedAt: publishedAt,
            isRead: isRead,
            feedUrl: "https://example.com/feed"
        )
    }

    // MARK: - All Unread

    @Test("Unread predicate returns only unread articles")
    func unreadOnlyUnread() throws {
        let context = try makeContext()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        context.insert(makeArticle(id: "a", isRead: false, publishedAt: now))
        context.insert(makeArticle(id: "b", isRead: true, publishedAt: now))
        context.insert(makeArticle(id: "c", isRead: false, publishedAt: now))
        try context.save()

        let unread = try context.fetch(FetchDescriptor<ArticleModel>(predicate: SmartFeedPredicates.unread()))
        #expect(Set(unread.map(\.id)) == ["a", "c"])
    }

    @Test("An article drops out of unread after being marked read")
    func unreadDropsAfterMarkRead() throws {
        let context = try makeContext()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let article = makeArticle(id: "a", isRead: false, publishedAt: now)
        context.insert(article)
        try context.save()

        let before = try context.fetch(FetchDescriptor<ArticleModel>(predicate: SmartFeedPredicates.unread()))
        #expect(before.count == 1)

        article.isRead = true
        try context.save()

        let after = try context.fetch(FetchDescriptor<ArticleModel>(predicate: SmartFeedPredicates.unread()))
        #expect(after.isEmpty)
    }

    @Test("Unread count badge math matches the unread fetch")
    func unreadCountBadge() throws {
        let context = try makeContext()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        for i in 0..<5 {
            context.insert(makeArticle(id: "u\(i)", isRead: false, publishedAt: now))
        }
        for i in 0..<3 {
            context.insert(makeArticle(id: "r\(i)", isRead: true, publishedAt: now))
        }
        try context.save()

        let count = try context.fetch(FetchDescriptor<ArticleModel>(predicate: SmartFeedPredicates.unread())).count
        #expect(count == 5)
    }

    // MARK: - Today

    @Test("Today predicate includes the startOfDay boundary and excludes yesterday")
    func todayBoundaryInclusive() throws {
        let context = try makeContext()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let now = Date(timeIntervalSince1970: 1_700_050_000) // some mid-day instant
        let startOfToday = cal.startOfDay(for: now)
        let oneSecondBefore = startOfToday.addingTimeInterval(-1)
        let later = startOfToday.addingTimeInterval(3600)
        let future = startOfToday.addingTimeInterval(86_400 * 2)

        context.insert(makeArticle(id: "boundary", publishedAt: startOfToday))
        context.insert(makeArticle(id: "yesterday", publishedAt: oneSecondBefore))
        context.insert(makeArticle(id: "today", publishedAt: later))
        context.insert(makeArticle(id: "future", publishedAt: future))
        try context.save()

        let descriptor = FetchDescriptor<ArticleModel>(
            predicate: SmartFeedPredicates.today(now: now, calendar: cal)
        )
        let matches = try context.fetch(descriptor)
        // Boundary-inclusive, today, and future-dated all qualify; yesterday does not.
        #expect(Set(matches.map(\.id)) == ["boundary", "today", "future"])
    }

    @Test("startOfToday is deterministic for an injected now")
    func startOfTodayDeterministic() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let now = Date(timeIntervalSince1970: 1_700_050_000)
        let start = SmartFeedPredicates.startOfToday(now: now, calendar: cal)
        #expect(start == cal.startOfDay(for: now))
        #expect(start <= now)
    }

    // MARK: - Nav-title mapping

    @Test("resolvedTitle prefers stored labels, falls back to selection title")
    func navTitleMapping() {
        let categoryLabels = ["ai": "Artificial Intelligence"]
        let folderNames = ["morning-reads": "Morning Reads"]
        let label: (String) -> String? = { categoryLabels[$0] }
        let name: (String) -> String? = { folderNames[$0] }

        #expect(SidebarSelection.all.resolvedTitle(categoryLabel: label, folderName: name) == "All News")
        #expect(SidebarSelection.allUnread.resolvedTitle(categoryLabel: label, folderName: name) == "All Unread")
        #expect(SidebarSelection.today.resolvedTitle(categoryLabel: label, folderName: name) == "Today")
        #expect(SidebarSelection.starred.resolvedTitle(categoryLabel: label, folderName: name) == "Starred")
        // Stored label preferred.
        #expect(SidebarSelection.category("ai").resolvedTitle(categoryLabel: label, folderName: name) == "Artificial Intelligence")
        // Missing label → capitalised slug fallback.
        #expect(SidebarSelection.category("gaming").resolvedTitle(categoryLabel: label, folderName: name) == "Gaming")
        // Stored folder name preferred.
        #expect(SidebarSelection.folder(slug: "morning-reads", feedUrls: []).resolvedTitle(categoryLabel: label, folderName: name) == "Morning Reads")
        // Missing folder name → capitalised slug fallback.
        #expect(SidebarSelection.folder(slug: "weekend", feedUrls: []).resolvedTitle(categoryLabel: label, folderName: name) == "Weekend")
    }
}
