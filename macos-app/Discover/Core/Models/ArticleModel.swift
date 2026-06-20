import Foundation
import SwiftData

/// A single article fetched from an RSS feed and persisted in SwiftData.
///
/// The `id` is a stable DJB2 two-pass hash of `feedUrl + "::" + guid` —
/// identical to the algorithm used in the web app's `lib/fetchFeeds.ts`.
@Model
final class ArticleModel {

    /// Stable, deduplicated identifier derived from feedURL + article GUID.
    @Attribute(.unique) var id: String

    var title: String
    var snippet: String
    var link: String

    /// Human-readable name of the originating feed (e.g. "The Verge AI").
    var source: String

    /// Category slug matching a `CategoryModel.slug` (e.g. "ai", "gaming").
    var category: String

    /// Best-available image URL: RSS enclosure → media:content → og:image fallback.
    var thumbnail: String?

    var publishedAt: Date
    var isRead: Bool

    /// Original RSS feed URL; used when refreshing a single feed.
    var feedUrl: String?

    /// Timestamp when this record was written to the store.
    var fetchedAt: Date

    init(
        id: String,
        title: String,
        snippet: String,
        link: String,
        source: String,
        category: String,
        thumbnail: String? = nil,
        publishedAt: Date,
        isRead: Bool = false,
        feedUrl: String? = nil,
        fetchedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.snippet = snippet
        self.link = link
        self.source = source
        self.category = category
        self.thumbnail = thumbnail
        self.publishedAt = publishedAt
        self.isRead = isRead
        self.feedUrl = feedUrl
        self.fetchedAt = fetchedAt
    }
}
