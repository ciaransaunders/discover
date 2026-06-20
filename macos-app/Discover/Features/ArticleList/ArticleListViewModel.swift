import Foundation
import SwiftData

/// Drives article fetching, upsert, and refresh-state management.
///
/// Lives on `@MainActor` so SwiftData operations are always on the correct thread.
/// Network work is delegated to `RSSFetcherActor` (off the main thread).
@Observable
@MainActor
final class ArticleListViewModel {

  // MARK: - Published state

  var isRefreshing = false
  var lastRefreshed: Date?
  var errorMessage: String?

  // MARK: - Refresh

  /// Fetches all enabled feeds, parses articles, and upserts new items into SwiftData.
  func refresh(context: ModelContext) async {
    guard !isRefreshing else { return }
    await performFetch(descriptors: nil, context: context)
  }

  /// Force-refreshes all feeds, ignoring the `isRefreshing` guard.
  /// Triggered by ⌘⇧R — clears error state and fetches everything fresh.
  func forceRefresh(context: ModelContext) async {
    await performFetch(descriptors: nil, context: context, isForce: true)
  }

  /// Refreshes a single category's feeds only.
  func refresh(category: String, context: ModelContext) async {
    guard !isRefreshing else { return }
    do {
      let feedModels = try context.fetch(
        FetchDescriptor<FeedModel>(
          predicate: #Predicate { $0.category == category && $0.enabled }
        ))
      let descriptors = feedModels.map {
        FeedDescriptor(url: $0.url, name: $0.name, category: $0.category, useOgImage: $0.useOgImage)
      }
      await performFetch(descriptors: descriptors, context: context)
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  /// Refreshes only the feeds that are currently in an error state.
  func refreshFailedFeeds(context: ModelContext) async {
    guard !isRefreshing else { return }
    do {
      let feedModels = try context.fetch(
        FetchDescriptor<FeedModel>(
          predicate: #Predicate { $0.enabled && $0.lastError != nil }
        ))
      let descriptors = feedModels.map {
        FeedDescriptor(url: $0.url, name: $0.name, category: $0.category, useOgImage: $0.useOgImage)
      }
      guard !descriptors.isEmpty else { return }
      await performFetch(descriptors: descriptors, context: context)
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  // MARK: - Private Fetch Logic

  /// Implementation of the refresh pipeline: fetch -> parse -> upsert -> status update.
  private func performFetch(descriptors: [FeedDescriptor]?, context: ModelContext, isForce: Bool = false) async {
    isRefreshing = true
    errorMessage = nil
    defer { isRefreshing = false }

    do {
      // 1. Resolve descriptors if not provided.
      let finalDescriptors: [FeedDescriptor]
      if let provided = descriptors {
        finalDescriptors = provided
      } else {
        let feedModels = try context.fetch(FetchDescriptor<FeedModel>(predicate: #Predicate { $0.enabled }))
        finalDescriptors = feedModels.map {
          FeedDescriptor(url: $0.url, name: $0.name, category: $0.category, useOgImage: $0.useOgImage)
        }
      }

      guard !finalDescriptors.isEmpty else { return }

      // 2. Fetch + parse on the actor (concurrent, off main thread).
      let results = await RSSFetcherActor.shared.fetchAll(feeds: finalDescriptors)

      // 3. Upsert back on @MainActor.
      let items = results.flatMap { $0.items }
      try upsert(items, into: context)

      // 4. Update FeedModel status for just the feeds we fetched.
      let fetchedUrls = finalDescriptors.map(\.url)
      let affectedFeeds = try context.fetch(FetchDescriptor<FeedModel>(
        predicate: #Predicate { fetchedUrls.contains($0.url) }
      ))
      
      for result in results {
        if let feedModel = affectedFeeds.first(where: { $0.url == result.feedUrl }) {
          feedModel.lastError = result.error
          if result.error == nil { feedModel.lastFetchedAt = .now }
        }
      }
      
      // 5. Cleanup & Save.
      purgeOldArticles(context: context)
      lastRefreshed = .now
      
      try context.save()
    } catch {
      errorMessage = error.localizedDescription
    }
  }


  // MARK: - Private: Upsert

  private func upsert(_ items: [ParsedItem], into context: ModelContext) throws {
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
        feedUrl: item.feedUrl.isEmpty ? nil : item.feedUrl
      )
      context.insert(article)
      newCount += 1
    }

    if newCount > 0 { try context.save() }
  }

  /// Removes articles older than the user's preference.
  /// Does NOT call context.save() — caller should save.
  private func purgeOldArticles(context: ModelContext) {
    let maxAgeDays = UserDefaults.standard.integer(forKey: "maxArticleAgeDays")
    
    // If not set, default to 7 days. If explicitly set to 0, it means "Keep Forever".
    let isSet = UserDefaults.standard.object(forKey: "maxArticleAgeDays") != nil
    let effectiveAge = !isSet ? 7 : maxAgeDays

    guard effectiveAge > 0 else { return }

    guard let cutoffDate = Calendar.current.date(byAdding: .day, value: -effectiveAge, to: .now)
    else { return }

    let descriptor = FetchDescriptor<ArticleModel>(
      predicate: #Predicate { $0.publishedAt < cutoffDate }
    )

    do {
      let toDelete = try context.fetch(descriptor)
      for article in toDelete {
        context.delete(article)
      }
    } catch {
      errorMessage = "Purge failed: \(error.localizedDescription)"
    }
  }
}
