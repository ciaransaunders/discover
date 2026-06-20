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

      // 3. Upsert back on @MainActor (shared with the add-by-URL flow).
      let items = results.flatMap { $0.items }
      try ArticleUpsertService.upsert(items, into: context)

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


  // MARK: - Private: Purge

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
