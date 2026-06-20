import Foundation
import SwiftData

/// A named content category that groups related feeds.
///
/// Default categories are seeded from `DefaultFeeds.categories` on first launch.
/// Users can add and remove categories via the Feed Manager sheet.
@Model
final class CategoryModel {

    /// URL-safe identifier (e.g. "ai", "gaming", "chelsea").
    @Attribute(.unique) var slug: String

    /// Human-readable label shown in the sidebar and filter tabs.
    var label: String

    /// Hex colour string (e.g. `"#8b5cf6"`) used for category accent decorations.
    var colorHex: String

    /// Determines sidebar sort order; lower values appear first.
    var priority: Int

    init(slug: String, label: String, colorHex: String, priority: Int = 0) {
        self.slug = slug
        self.label = label
        self.colorHex = colorHex
        self.priority = priority
    }
}
