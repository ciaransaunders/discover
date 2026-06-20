import Foundation
import SwiftData

/// Seeds the bundled default categories and feeds into SwiftData on first launch.
///
/// Extracted from `ArticleListView.seedDefaultsIfNeeded()` so it can be invoked once from
/// `ContentView` *before* the background refresh scheduler starts (guaranteeing feeds exist
/// before the first fetch), while the article list keeps calling the same idempotent helper.
///
/// Idempotent: inserts only missing rows and preserves user changes to existing ones.
@MainActor
enum DefaultFeedsSeeder {

    /// Inserts any missing default categories/feeds. Saves only if something was inserted.
    static func seedIfNeeded(context: ModelContext) throws {
        let existingCategories = try context.fetch(FetchDescriptor<CategoryModel>())
        let existingFeeds = try context.fetch(FetchDescriptor<FeedModel>())

        let existingSlugs = Set(existingCategories.map(\.slug))
        let existingUrls = Set(existingFeeds.map(\.url))

        var didInsertAnything = false

        for (index, data) in DefaultFeeds.categories.enumerated() {
            guard !existingSlugs.contains(data.slug) else { continue }
            let category = CategoryModel(
                slug: data.slug,
                label: data.label,
                colorHex: data.color,
                priority: index
            )
            context.insert(category)
            didInsertAnything = true
        }

        for data in DefaultFeeds.feeds {
            guard !existingUrls.contains(data.url) else { continue }
            let feed = FeedModel(
                url: data.url,
                name: data.name,
                category: data.category,
                useOgImage: data.useOgImage
            )
            context.insert(feed)
            didInsertAnything = true
        }

        if didInsertAnything {
            try context.save()
        }
    }
}
