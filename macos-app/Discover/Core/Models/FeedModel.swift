import Foundation
import SwiftData

/// A configured RSS feed source managed by the user.
///
/// Default feeds are seeded from `DefaultFeeds.feeds` on first launch.
/// Users can add, remove, and re-enable feeds via the Feed Manager sheet.
@Model
final class FeedModel {

    /// The RSS/Atom feed URL; must be unique across all feeds.
    @Attribute(.unique) var url: String

    /// Display name shown in the Feed Manager and article source labels.
    var name: String

    /// Category slug this feed belongs to (matches a `CategoryModel.slug`).
    var category: String

    /// When `true`, the fetcher performs a secondary HTTP request to the
    /// article page to extract a higher-quality `og:image` meta tag.
    /// Used for feeds like BBC News and Sky News that provide low-res enclosure images.
    var useOgImage: Bool

    var enabled: Bool

    /// Timestamp of the most recent successful fetch.
    var lastFetchedAt: Date?

    /// Stores the last error description if a fetch failed; `nil` on success.
    var lastError: String?

    /// When the feed was added to the store. Additive & optional (schema v2, cluster E);
    /// `nil` for feeds seeded/added before v2. Used to sort user-added feeds.
    var createdAt: Date?

    init(
        url: String,
        name: String,
        category: String,
        useOgImage: Bool = false,
        enabled: Bool = true,
        createdAt: Date? = nil
    ) {
        self.url = url
        self.name = name
        self.category = category
        self.useOgImage = useOgImage
        self.enabled = enabled
        self.createdAt = createdAt
    }
}
