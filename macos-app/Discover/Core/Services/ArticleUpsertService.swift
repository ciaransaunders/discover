import Foundation
import SwiftData

/// Shared, `@MainActor` article upsert used by both the article-list refresh path and the
/// add-by-URL flow in the Feed Manager.
///
/// Extracted verbatim from `ArticleListViewModel.upsert(_:into:)` (cluster E) so the two
/// call sites share one dedup/insert implementation. Behaviour is byte-for-byte identical:
/// the same `URLNormaliser` / `IDGenerator` / `SnippetTruncator` / `HTMLStripper` usage,
/// the same in-batch dedup, the same persisted-ID dedup, and the same `context.save()`
/// on a non-zero insert count. The only addition is that `upsert(_:into:)` *returns* the
/// number of newly inserted articles (used by callers that want to report new items).
@MainActor
enum ArticleUpsertService {

    /// Deduplicates `items`, inserts only genuinely new articles into `context`, saves if
    /// anything was inserted, and returns the number of inserted articles.
    @discardableResult
    static func upsert(_ items: [ParsedItem], into context: ModelContext) throws -> Int {
        var newCount = 0

        // ── Step 1: compute IDs and deduplicate within the incoming batch ──────────
        // Two root causes for in-batch duplicates:
        //   a) Some feeds (e.g. BBC) occasionally emit the same <item> twice.
        //   b) A category-change creates a new ArticleListView whose .task fires a
        //      second refresh before the first save completes, so the same articles
        //      appear in two concurrent batches.
        // Tracking `seenInBatch` ensures we only attempt to insert each ID once.
        struct Keyed { let id: String; let item: ParsedItem }
        var seenInBatch = Set<String>()
        let keyed: [Keyed] = items.compactMap { item in
            guard !item.link.isEmpty else { return nil }
            let normLink = URLNormaliser.normalise(item.link)
            let guid = item.guid.isEmpty ? normLink : item.guid
            let id = IDGenerator.generate(feedUrl: normLink, guid: guid)
            guard seenInBatch.insert(id).inserted else { return nil }
            return Keyed(id: id, item: item)
        }

        // ── Step 2: fetch which of these IDs are already persisted ────────────────
        let incomingIDs = keyed.map(\.id)
        let existingArticles = try context.fetch(
            FetchDescriptor<ArticleModel>(
                predicate: #Predicate { incomingIDs.contains($0.id) }
            ))
        let existingIDs = Set(existingArticles.map(\.id))

        // ── Step 3: insert only genuinely new articles ────────────────────────────
        for k in keyed {
            guard !existingIDs.contains(k.id) else { continue }

            let item = k.item
            let normLink = URLNormaliser.normalise(item.link)

            let snippet = SnippetTruncator.truncate(
                HTMLStripper.strip(item.description.isEmpty ? item.content : item.description)
            )
            let sourceName =
                item.feedName.isEmpty
                ? URLNormaliser.sourceName(from: normLink)
                : item.feedName

            let article = ArticleModel(
                id: k.id,
                title: item.title.isEmpty ? "Untitled" : item.title,
                snippet: snippet,
                link: normLink,
                source: sourceName,
                category: item.category,
                thumbnail: item.thumbnail,
                publishedAt: item.pubDate ?? .now,
                feedUrl: item.feedUrl.isEmpty ? nil : item.feedUrl,
                // Cluster A1 — persist the full body (content:encoded / atom:content) so the
                // in-app Reader has something richer than the snippet. nil when the feed
                // provides no full content.
                content: item.content.isEmpty ? nil : item.content
            )
            context.insert(article)
            newCount += 1
        }

        if newCount > 0 { try context.save() }
        return newCount
    }
}
