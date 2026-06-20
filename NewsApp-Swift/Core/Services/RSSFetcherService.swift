import Foundation

protocol RSSFetcherServiceType: Sendable {
  func fetchArticles(for feeds: [FeedDescriptor]) async throws -> [ArticleDTO]
}

struct FeedDescriptor: Sendable {
  let url: String
  let categorySlug: String
}

struct ArticleDTO: Sendable {
  let id: String
  let title: String
  let snippet: String
  let link: String
  let source: String
  let categorySlug: String
  let thumbnail: String?
  let publishedAt: Date
}

actor RSSFetcherService: RSSFetcherServiceType {

  func fetchArticles(for feeds: [FeedDescriptor]) async throws -> [ArticleDTO] {
    // Implement real URLSession RSS parsing here
    // For scaffold purposes, return mock data
    return [
      ArticleDTO(
        id: UUID().uuidString,
        title: "Mock Article",
        snippet: "This is a placeholder article for testing",
        link: "https://example.com",
        source: "Example Source",
        categorySlug: feeds.first?.categorySlug ?? "general",
        thumbnail: nil,
        publishedAt: .now
      )
    ]
  }
}
