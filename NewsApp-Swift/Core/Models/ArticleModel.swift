import Foundation
import SwiftData

@Model
final class ArticleModel {
  @Attribute(.unique) var id: String
  var title: String
  var snippet: String
  var link: String
  var source: String
  var categorySlug: String
  var thumbnail: String?
  var publishedAt: Date
  var isRead: Bool
  var fetchedAt: Date

  init(
    id: String,
    title: String,
    snippet: String,
    link: String,
    source: String,
    categorySlug: String,
    thumbnail: String? = nil,
    publishedAt: Date,
    isRead: Bool = false,
    fetchedAt: Date = .now
  ) {
    self.id = id
    self.title = title
    self.snippet = snippet
    self.link = link
    self.source = source
    self.categorySlug = categorySlug
    self.thumbnail = thumbnail
    self.publishedAt = publishedAt
    self.isRead = isRead
    self.fetchedAt = fetchedAt
  }
}
