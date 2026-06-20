import Foundation
import SwiftData
import Testing

@testable import NewsApp

@Suite("NewsApp — ViewModel Tests")
struct ArticleListViewModelTests {

  @MainActor
  @Test("ViewModel successfully fetches and saves mock DTOs into ModelContext")
  func testFetchAndSave() async throws {
    // Arrange
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
      for: ArticleModel.self, FeedModel.self, CategoryModel.self, configurations: config)
    let context = container.mainContext

    // Seed a feed so the service triggers
    context.insert(
      FeedModel(url: "https://example.com/rss", name: "Test Feed", categorySlug: "tech"))
    try context.save()

    let viewModel = ArticleListViewModel()  // Uses default generic stub service

    // Act
    #expect(viewModel.isRefreshing == false)
    await viewModel.refresh(context: context)
    #expect(viewModel.isRefreshing == false)

    // Assert
    let descriptor = FetchDescriptor<ArticleModel>()
    let articles = try context.fetch(descriptor)

    #expect(articles.count == 1, "Expected mock service to return 1 article")
    #expect(articles[0].title == "Mock Article")
    #expect(articles[0].source == "Example Source")
  }
}
