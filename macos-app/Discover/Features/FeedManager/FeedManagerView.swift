import SwiftData
import SwiftUI

#if canImport(AppKit)
  import AppKit
#endif
#if canImport(UIKit)
  import UIKit
#endif

/// Slide-in sheet for managing feeds and categories.
/// Mirrors `FeedManager.tsx` with a Feeds / Categories tab strip.
struct FeedManagerView: View {

  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss

  @State private var viewModel = FeedManagerViewModel()

  @Query(sort: \FeedModel.name) private var feeds: [FeedModel]
  @Query(sort: \CategoryModel.priority) private var categories: [CategoryModel]
  @Query(sort: \FolderModel.priority) private var folders: [FolderModel]

  /// Every unread article — one grouped fetch used to compute which feeds still have unread items
  /// (cluster C2 "hide read feeds"), instead of a query per feed.
  @Query(filter: #Predicate<ArticleModel> { !$0.isRead }) private var unreadArticles: [ArticleModel]

  /// Cluster C2 — when on, feeds whose every article is read are hidden from the Feeds list.
  @AppStorage("hideReadFeeds") private var hideReadFeeds = false

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        // Tab picker
        Picker("", selection: $viewModel.selectedTab) {
          Text("Feeds").tag(FeedManagerViewModel.FeedManagerTab.feeds)
          Text("Categories").tag(FeedManagerViewModel.FeedManagerTab.categories)
          Text("Folders").tag(FeedManagerViewModel.FeedManagerTab.folders)
        }
        .pickerStyle(.segmented)
        .padding()

        Divider()

        switch viewModel.selectedTab {
        case .feeds: feedsTab
        case .categories: categoriesTab
        case .folders: foldersTab
        }
      }
      .navigationTitle("Feed Manager")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
    .frame(minWidth: 320, idealWidth: 480, minHeight: 400)
    .alert(
      "Error",
      isPresented: Binding(
        get: { viewModel.errorMessage != nil },
        set: { if !$0 { viewModel.errorMessage = nil } }
      )
    ) {
      Button("OK") { viewModel.errorMessage = nil }
    } message: {
      Text(viewModel.errorMessage ?? "")
    }
  }

  // MARK: - Feeds Tab

  private var feedsTab: some View {
    List {
      // Add-feed form (with autodiscovery — accepts a feed URL or a website URL).
      Section("Add Feed") {
        TextField("Feed or website URL", text: $viewModel.newFeedURL)
          .textFieldStyle(.plain)
          .onSubmit { Task { await viewModel.discoverAndAddFeed(context: modelContext) } }
        TextField("Name (optional)", text: $viewModel.newFeedName)
          .textFieldStyle(.plain)
        // Category picker from existing categories
        Picker("Category", selection: $viewModel.newFeedCategory) {
          Text("General").tag("general")
          ForEach(categories) { cat in
            Text(cat.label).tag(cat.slug)
          }
        }
        Button {
          Task { await viewModel.discoverAndAddFeed(context: modelContext) }
        } label: {
          if viewModel.isDiscovering {
            HStack(spacing: 6) {
              ProgressView().controlSize(.small)
              Text("Finding feed…")
            }
          } else {
            Text("Add Feed")
          }
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.newFeedURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isDiscovering)
        Text("Paste an RSS/Atom URL, or a site's homepage — Discover will try to find its feed.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      // Search existing feeds (in-memory; cluster E3) + hide-read-feeds toggle (cluster C2).
      Section {
        HStack(spacing: 6) {
          Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
          TextField("Search feeds", text: $viewModel.feedSearchText)
            .textFieldStyle(.plain)
          if !viewModel.feedSearchText.isEmpty {
            Button {
              viewModel.feedSearchText = ""
            } label: {
              Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
          }
        }
        Toggle("Hide feeds with no unread articles", isOn: $hideReadFeeds)
      }

      // The set of feed URLs that still have unread articles (single grouped pass).
      let unreadFeedURLs = ArticleVisibilityFilter.feedURLsWithUnread(
        unreadArticles.map { (feedUrl: $0.feedUrl, isRead: $0.isRead) }
      )

      // Existing feeds grouped by category (search-filtered, then hide-read filtered).
      let visibleFeeds = feeds.filter { feed in
        let matchesSearch = FeedSearchMatcher.matches(
          FeedSearchSubject(name: feed.name, url: feed.url, category: feed.category),
          query: viewModel.feedSearchText
        )
        guard matchesSearch else { return false }
        if hideReadFeeds {
          return ArticleVisibilityFilter.feedHasUnread(feed.url, in: unreadFeedURLs)
        }
        return true
      }
      let grouped = Dictionary(grouping: visibleFeeds, by: { $0.category })
      let priorityBySlug = Dictionary(uniqueKeysWithValues: categories.map { ($0.slug, $0.priority) })
      let labelBySlug = Dictionary(uniqueKeysWithValues: categories.map { ($0.slug, $0.label) })
      let sortedSlugs = grouped.keys.sorted { lhs, rhs in
        let lp = priorityBySlug[lhs] ?? Int.max
        let rp = priorityBySlug[rhs] ?? Int.max
        if lp != rp { return lp < rp }
        return lhs < rhs
      }
      ForEach(sortedSlugs, id: \.self) { categorySlug in
        Section(labelBySlug[categorySlug] ?? categorySlug.capitalized) {
          ForEach(grouped[categorySlug] ?? []) { feed in
            FeedRowView(feed: feed) {
              viewModel.toggleFeed(feed, context: modelContext)
            } onDelete: {
              viewModel.deleteFeed(feed, context: modelContext)
            }
          }
        }
      }
    }
  }

  // MARK: - Categories Tab

  private var categoriesTab: some View {
    List {
      // Add-category form
      Section("Add Category") {
        TextField("Slug (e.g. sports)", text: $viewModel.newCategorySlug)
          .textFieldStyle(.plain)
        TextField("Label (e.g. Sports)", text: $viewModel.newCategoryLabel)
          .textFieldStyle(.plain)
        ColorPicker(
          "Colour",
          selection: Binding(
            get: { Color(hex: viewModel.newCategoryColor) },
            set: { newColor in
              // Convert SwiftUI Color → hex string (approximate).
              viewModel.newCategoryColor = newColor.hexString
            }
          ))
        Button("Add Category") {
          viewModel.addCategory(context: modelContext)
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.newCategorySlug.isEmpty || viewModel.newCategoryLabel.isEmpty)
      }

      // Existing categories
      Section("Categories") {
        ForEach(categories) { cat in
          HStack {
            Circle()
              .fill(Color(hex: cat.colorHex))
              .frame(width: 12, height: 12)
            Text(cat.label)
            Spacer()
            Text(cat.slug)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        .onDelete { offsets in
          for idx in offsets {
            viewModel.deleteCategory(categories[idx], context: modelContext)
          }
        }
      }
    }
  }

  // MARK: - Folders Tab (cluster C3)

  private var foldersTab: some View {
    List {
      // Add-folder form.
      Section("Add Folder") {
        TextField("Folder name (e.g. Morning Reads)", text: $viewModel.newFolderName)
          .textFieldStyle(.plain)
          .onSubmit { viewModel.addFolder(context: modelContext) }
        Button("Add Folder") {
          viewModel.addFolder(context: modelContext)
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        Text("Folders group feeds for the sidebar. A feed can sit in any number of folders and keeps its category.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      if folders.isEmpty {
        Section {
          Text("No folders yet. Create one above to group your feeds.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      } else {
        Section("Folders") {
          ForEach(folders) { folder in
            FolderRowView(
              folder: folder,
              allFeeds: feeds,
              onRename: { newName in
                viewModel.renameFolder(folder, to: newName, context: modelContext)
              },
              onDelete: {
                viewModel.deleteFolder(folder, context: modelContext)
              },
              onToggleMembership: { feed in
                if folder.feedUrls.contains(feed.url) {
                  viewModel.removeFeed(feed.url, from: folder, context: modelContext)
                } else {
                  viewModel.addFeed(feed.url, to: folder, context: modelContext)
                }
              }
            )
          }
        }
      }
    }
  }
}

// MARK: - Feed Row

private struct FeedRowView: View {
  let feed: FeedModel
  let onToggle: () -> Void
  let onDelete: () -> Void

  var body: some View {
    HStack {
      FaviconImage(urlString: feed.url)
      VStack(alignment: .leading, spacing: 2) {
        Text(feed.name).font(.body)
        Text(feed.url)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
        if let err = feed.lastError, !err.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          Label(err, systemImage: "exclamationmark.triangle.fill")
            .font(.caption2)
            .foregroundStyle(.orange)
            .lineLimit(1)
        } else if let ts = feed.lastFetchedAt {
          HStack(spacing: 4) {
            Image(systemName: "checkmark.circle")
            TimeAgoText(date: ts)
          }
          .font(.caption2)
          .foregroundStyle(.secondary)
        }
      }
      Spacer()
      Toggle(
        "",
        isOn: Binding(
          get: { feed.enabled },
          set: { _ in onToggle() }
        )
      )
      .labelsHidden()
      Button(role: .destructive) {
        onDelete()
      } label: {
        Image(systemName: "trash")
      }
      .buttonStyle(.plain)
    }
  }
}

// MARK: - Folder Row (cluster C3)

/// One folder row: shows name + member count, with a disclosure listing every feed as a toggle to
/// add/remove it, plus rename + delete affordances.
private struct FolderRowView: View {
  @Bindable var folder: FolderModel
  let allFeeds: [FeedModel]
  let onRename: (String) -> Void
  let onDelete: () -> Void
  let onToggleMembership: (FeedModel) -> Void

  @State private var isEditingName = false
  @State private var draftName = ""

  var body: some View {
    DisclosureGroup {
      if allFeeds.isEmpty {
        Text("No feeds to add yet.")
          .font(.caption)
          .foregroundStyle(.secondary)
      } else {
        ForEach(allFeeds) { feed in
          Button {
            onToggleMembership(feed)
          } label: {
            HStack(spacing: 8) {
              Image(systemName: folder.feedUrls.contains(feed.url) ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(folder.feedUrls.contains(feed.url) ? Color.accentColor : Color.secondary)
              FaviconImage(urlString: feed.url)
              Text(feed.name).font(.body)
              Spacer()
            }
          }
          .buttonStyle(.plain)
        }
      }
    } label: {
      HStack {
        Image(systemName: folder.iconSystemName)
          .foregroundStyle(.secondary)
        if isEditingName {
          TextField("Folder name", text: $draftName)
            .textFieldStyle(.roundedBorder)
            .onSubmit { commitRename() }
        } else {
          Text(folder.name)
          Text("\(folder.feedUrls.count) feed\(folder.feedUrls.count == 1 ? "" : "s")")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        if isEditingName {
          Button("Save") { commitRename() }
            .buttonStyle(.plain)
        } else {
          Button {
            draftName = folder.name
            isEditingName = true
          } label: {
            Image(systemName: "pencil")
          }
          .buttonStyle(.plain)
        }
        Button(role: .destructive) {
          onDelete()
        } label: {
          Image(systemName: "trash")
        }
        .buttonStyle(.plain)
      }
    }
  }

  private func commitRename() {
    onRename(draftName)
    isEditingName = false
  }
}

// MARK: - Color hex helper

extension Color {
  /// Very lightweight Color → CSS hex (RRGGBB). Good enough for category colours.
  fileprivate var hexString: String {
    #if os(macOS)
      guard let components = NSColor(self).usingColorSpace(.sRGB)?.cgColor.components,
        components.count >= 3
      else { return "#6B7280" }
    #else
      guard let components = UIColor(self).cgColor.components,
        components.count >= 3
      else { return "#6B7280" }
    #endif
    let r = Int(components[0] * 255)
    let g = Int(components[1] * 255)
    let b = Int(components[2] * 255)
    return String(format: "#%02X%02X%02X", r, g, b)
  }
}
