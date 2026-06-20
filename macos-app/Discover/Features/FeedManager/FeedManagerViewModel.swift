import Foundation
import SwiftData

/// Manages CRUD operations for `FeedModel` and `CategoryModel` in SwiftData.
/// Lives on `@MainActor` — all SwiftData writes happen here.
@Observable
@MainActor
final class FeedManagerViewModel {

  // MARK: - UI state

  var newFeedURL = ""
  var newFeedName = ""
  var newFeedCategory = "general"
  var newCategorySlug = ""
  var newCategoryLabel = ""
  var newCategoryColor = "#6B7280"
  var errorMessage: String?
  var selectedTab = FeedManagerTab.feeds

  enum FeedManagerTab { case feeds, categories }

  // MARK: - Feed CRUD

  func addFeed(context: ModelContext) {
    let urlStr = newFeedURL.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !urlStr.isEmpty, URL(string: urlStr) != nil else {
      errorMessage = "Please enter a valid feed URL."
      return
    }
    let name = newFeedName.trimmingCharacters(in: .whitespacesAndNewlines)
    let category = newFeedCategory.trimmingCharacters(in: .whitespacesAndNewlines)

    do {
      // BUG_REPORT: Prevent silent overwrite of existing feeds by checking uniqueness beforehand
      let existingFeeds = try context.fetch(FetchDescriptor<FeedModel>())
      if existingFeeds.contains(where: { $0.url == urlStr }) {
        errorMessage = "This feed has already been added."
        return
      }

      let resolvedCategory = category.isEmpty ? "general" : category
      try ensureCategoryExistsIfNeeded(slug: resolvedCategory, context: context)

      let feed = FeedModel(
        url: urlStr,
        name: name.isEmpty ? URLNormaliser.sourceName(from: urlStr) : name,
        category: resolvedCategory
      )
      context.insert(feed)
      try context.save()
      clearFeedForm()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func toggleFeed(_ feed: FeedModel, context: ModelContext) {
    feed.enabled.toggle()
    do { try context.save() }
    catch { errorMessage = error.localizedDescription }
  }

  func deleteFeed(_ feed: FeedModel, context: ModelContext) {
    context.delete(feed)
    do { try context.save() }
    catch { errorMessage = error.localizedDescription }
  }

  // MARK: - Category CRUD

  func addCategory(context: ModelContext) {
    let slug = newCategorySlug.trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased().replacingOccurrences(of: " ", with: "-")
    let label = newCategoryLabel.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !slug.isEmpty, !label.isEmpty else {
      errorMessage = "Slug and label are required."
      return
    }

    do {
      let existing = try context.fetch(FetchDescriptor<CategoryModel>())

      // BUG_REPORT: Prevent silent overwrite of existing categories
      if existing.contains(where: { $0.slug == slug }) {
        errorMessage = "A category with this slug already exists."
        return
      }

      // Determine next priority.
      let priority = (existing.max(by: { $0.priority < $1.priority })?.priority ?? 0) + 1

      let cat = CategoryModel(
        slug: slug,
        label: label,
        colorHex: newCategoryColor,
        priority: priority
      )
      context.insert(cat)
      try context.save()
      clearCategoryForm()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func deleteCategory(_ category: CategoryModel, context: ModelContext) {
    do {
      // BUG_REPORT: Fix orphaned feeds by migrating them to "general" before deleting the category
      let slug = category.slug
      let affectedFeeds = try context.fetch(
        FetchDescriptor<FeedModel>(
          predicate: #Predicate { $0.category == slug }
        ))
      if !affectedFeeds.isEmpty {
        try ensureCategoryExistsIfNeeded(slug: "general", context: context)
        for feed in affectedFeeds { feed.category = "general" }
      }

      context.delete(category)
      try context.save()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  // MARK: - Private

  private func clearFeedForm() {
    newFeedURL = ""
    newFeedName = ""
    newFeedCategory = "general"
  }

  private func clearCategoryForm() {
    newCategorySlug = ""
    newCategoryLabel = ""
    newCategoryColor = "#6B7280"
  }

  private func ensureCategoryExistsIfNeeded(slug: String, context: ModelContext) throws {
    let normalized = slug.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !normalized.isEmpty else { return }

    let existing = try context.fetch(
      FetchDescriptor<CategoryModel>(
        predicate: #Predicate { $0.slug == normalized }
      ))
    guard existing.isEmpty else { return }

    let all = try context.fetch(FetchDescriptor<CategoryModel>())
    let nextPriority = (all.max(by: { $0.priority < $1.priority })?.priority ?? 0) + 1
    let label =
      normalized == "general"
      ? "General"
      : normalized.replacingOccurrences(of: "-", with: " ").capitalized

    let cat = CategoryModel(slug: normalized, label: label, colorHex: "#6B7280", priority: nextPriority)
    context.insert(cat)
  }
}
