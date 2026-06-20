import Foundation
import SwiftData

/// A user-defined folder that groups feeds for sidebar organisation.
///
/// Folders are orthogonal to categories: a feed keeps its single `category` and may
/// additionally appear in any number of folders. Membership is stored as a denormalised
/// list of `FeedModel.url` values (the existing unique key) — consistent with the rest of
/// the schema, which uses string keys rather than `@Relationship`s.
///
/// Additive (schema v2, cluster C).
@Model
final class FolderModel {

    /// URL-safe identifier, unique across folders (e.g. "morning-reads").
    @Attribute(.unique) var slug: String

    /// Human-readable folder name shown in the sidebar.
    var name: String

    /// Member feed URLs (each matches a `FeedModel.url`).
    var feedUrls: [String]

    /// SF Symbol shown next to the folder in the sidebar.
    var iconSystemName: String

    /// Determines sidebar sort order; lower values appear first.
    var priority: Int

    init(
        slug: String,
        name: String,
        feedUrls: [String] = [],
        iconSystemName: String = "folder.fill",
        priority: Int = 0
    ) {
        self.slug = slug
        self.name = name
        self.feedUrls = feedUrls
        self.iconSystemName = iconSystemName
        self.priority = priority
    }
}
