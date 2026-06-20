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

  // Folder form state (cluster C3).
  var newFolderName = ""

  var errorMessage: String?
  var selectedTab = FeedManagerTab.feeds

  /// `true` while an add-by-URL discovery request is in flight (drives the Add button spinner).
  var isDiscovering = false
  /// Search query applied (in-memory) to the feed list.
  var feedSearchText = ""

  enum FeedManagerTab { case feeds, categories, folders }

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

  /// Add-by-URL with autodiscovery (cluster E1).
  ///
  /// Resolves the entered URL to a concrete feed via `FeedDiscoveryActor` (off-main network),
  /// validates uniqueness, infers the display name from the feed `<title>`, stamps
  /// `createdAt = .now`, inserts the `FeedModel`, then upserts any prefetched items through the
  /// shared `ArticleUpsertService`. Errors are surfaced via `errorMessage`.
  func discoverAndAddFeed(context: ModelContext) async {
    guard !isDiscovering else { return }
    let entered = newFeedURL.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !entered.isEmpty else {
      errorMessage = "Please enter a feed or website URL."
      return
    }

    isDiscovering = true
    defer { isDiscovering = false }

    let result: FeedDiscoveryResult
    do {
      result = try await FeedDiscoveryActor.shared.discover(from: entered)
    } catch {
      errorMessage = error.localizedDescription
      return
    }

    do {
      // Reject duplicates against the resolved URL.
      let resolvedURL = result.feedUrl
      let existingFeeds = try context.fetch(FetchDescriptor<FeedModel>())
      if existingFeeds.contains(where: { $0.url == resolvedURL }) {
        errorMessage = "This feed has already been added."
        return
      }

      let category = newFeedCategory.trimmingCharacters(in: .whitespacesAndNewlines)
      let resolvedCategory = category.isEmpty ? "general" : category
      try ensureCategoryExistsIfNeeded(slug: resolvedCategory, context: context)

      // Prefer a user-supplied name, else the feed's <title>, else a host-derived label.
      let typedName = newFeedName.trimmingCharacters(in: .whitespacesAndNewlines)
      let inferredName =
        typedName.isEmpty
        ? (result.feedTitle?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
          ?? URLNormaliser.sourceName(from: resolvedURL)
        : typedName

      let feed = FeedModel(
        url: resolvedURL,
        name: inferredName,
        category: resolvedCategory,
        createdAt: .now
      )
      context.insert(feed)
      try context.save()

      // Persist prefetched items so the new feed isn't empty until the next refresh.
      // Stamp feed metadata so source/category match the inserted FeedModel.
      let stampedItems = result.items.map { item -> ParsedItem in
        var copy = item
        copy.feedUrl = resolvedURL
        copy.category = resolvedCategory
        copy.feedName = inferredName
        return copy
      }
      try ArticleUpsertService.upsert(stampedItems, into: context)

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

  // MARK: - Folder CRUD (cluster C3)

  /// Creates a folder from `newFolderName`. The slug is derived from the name and must be unique,
  /// mirroring the category uniqueness/priority pattern.
  func addFolder(context: ModelContext) {
    let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else {
      errorMessage = "Folder name is required."
      return
    }
    let slug = Self.folderSlug(from: name)
    guard !slug.isEmpty else {
      errorMessage = "Folder name must contain at least one letter or number."
      return
    }

    do {
      let existing = try context.fetch(FetchDescriptor<FolderModel>())
      if existing.contains(where: { $0.slug == slug }) {
        errorMessage = "A folder with this name already exists."
        return
      }

      let priority = (existing.max(by: { $0.priority < $1.priority })?.priority ?? 0) + 1
      let folder = FolderModel(slug: slug, name: name, feedUrls: [], priority: priority)
      context.insert(folder)
      try context.save()
      newFolderName = ""
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  /// Renames a folder in place. The `slug` (and therefore membership/selection identity) is left
  /// unchanged so an open selection keeps working.
  func renameFolder(_ folder: FolderModel, to newName: String, context: ModelContext) {
    let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      errorMessage = "Folder name is required."
      return
    }
    folder.name = trimmed
    do { try context.save() }
    catch { errorMessage = error.localizedDescription }
  }

  func deleteFolder(_ folder: FolderModel, context: ModelContext) {
    context.delete(folder)
    do { try context.save() }
    catch { errorMessage = error.localizedDescription }
  }

  /// Adds a feed URL to a folder (no duplicates).
  func addFeed(_ feedUrl: String, to folder: FolderModel, context: ModelContext) {
    guard !folder.feedUrls.contains(feedUrl) else { return }
    folder.feedUrls.append(feedUrl)
    do { try context.save() }
    catch { errorMessage = error.localizedDescription }
  }

  /// Removes a feed URL from a folder.
  func removeFeed(_ feedUrl: String, from folder: FolderModel, context: ModelContext) {
    folder.feedUrls.removeAll { $0 == feedUrl }
    do { try context.save() }
    catch { errorMessage = error.localizedDescription }
  }

  /// Derives a URL-safe slug from a folder name (lowercased, spaces → hyphens, alphanumerics only).
  static func folderSlug(from name: String) -> String {
    let lowered = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    var slug = ""
    var lastWasHyphen = false
    for ch in lowered {
      if ch.isLetter || ch.isNumber {
        slug.append(ch)
        lastWasHyphen = false
      } else if !lastWasHyphen, !slug.isEmpty {
        slug.append("-")
        lastWasHyphen = true
      }
    }
    while slug.hasSuffix("-") { slug.removeLast() }
    return slug
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
