import Foundation
import SwiftData

@Model
final class CategoryModel {
  @Attribute(.unique) var slug: String
  var label: String
  var colorHex: String
  var priority: Int

  init(slug: String, label: String, colorHex: String, priority: Int = 0) {
    self.slug = slug
    self.label = label
    self.colorHex = colorHex
    self.priority = priority
  }
}
