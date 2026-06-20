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

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        // Tab picker
        Picker("", selection: $viewModel.selectedTab) {
          Text("Feeds").tag(FeedManagerViewModel.FeedManagerTab.feeds)
          Text("Categories").tag(FeedManagerViewModel.FeedManagerTab.categories)
        }
        .pickerStyle(.segmented)
        .padding()

        Divider()

        switch viewModel.selectedTab {
        case .feeds: feedsTab
        case .categories: categoriesTab
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
      // Add-feed form
      Section("Add Feed") {
        TextField("RSS feed URL", text: $viewModel.newFeedURL)
          .textFieldStyle(.plain)
        TextField("Name (optional)", text: $viewModel.newFeedName)
          .textFieldStyle(.plain)
        // Category picker from existing categories
        Picker("Category", selection: $viewModel.newFeedCategory) {
          Text("General").tag("general")
          ForEach(categories) { cat in
            Text(cat.label).tag(cat.slug)
          }
        }
        Button("Add Feed") {
          viewModel.addFeed(context: modelContext)
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.newFeedURL.isEmpty)
      }

      // Existing feeds grouped by category
      let grouped = Dictionary(grouping: feeds, by: { $0.category })
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
