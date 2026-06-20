import Foundation
import SwiftData

@Observable
final class ArticleListViewModel {

  var isRefreshing = false
  var errorMessage: String?

  // Inject service using Protocol
  private let fetcherService: RSSFetcherServiceType

  init(fetcherService: RSSFetcherServiceType = RSSFetcherService()) {
    self.fetcherService = fetcherService
  }

  @MainActor
  func refresh(context: ModelContext) async {
    guard !isRefreshing else { return }
    isRefreshing = true
    errorMessage = nil
    defer { isRefreshing = false }

    do {
      let feedModels = try context.fetch(FetchDescriptor<FeedModel>())
      let descriptors = feedModels.map {
        FeedDescriptor(url: $0.url, categorySlug: $0.categorySlug)
      }

      guard !descriptors.isEmpty else { return }

      let dtos = try await fetcherService.fetchArticles(for: descriptors)

      // Insert mock DTOs into SwiftData context
      for dto in dtos {
        let article = ArticleModel(
          id: dto.id,
          title: dto.title,
          snippet: dto.snippet,
          link: dto.link,
          source: dto.source,
          categorySlug: dto.categorySlug,
          thumbnail: dto.thumbnail,
          publishedAt: dto.publishedAt
        )
        context.insert(article)
      }

      try context.save()

    } catch {
      errorMessage = error.localizedDescription
    }
  }

  @MainActor
  func toggleReadState(for article: ArticleModel, context: ModelContext) {
    article.isRead.toggle()
    try? context.save()
  }
}
