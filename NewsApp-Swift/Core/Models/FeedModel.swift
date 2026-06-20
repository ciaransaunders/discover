import Foundation
import SwiftData

@Model
final class FeedModel {
  @Attribute(.unique) var url: String
  var name: String
  var categorySlug: String
  var isEnabled: Bool

  init(url: String, name: String, categorySlug: String, isEnabled: Bool = true) {
    self.url = url
    self.name = name
    self.categorySlug = categorySlug
    self.isEnabled = isEnabled
  }
}
