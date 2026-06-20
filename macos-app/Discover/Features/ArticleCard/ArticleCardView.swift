import SwiftUI

#if canImport(AppKit)
  import AppKit
#endif
#if canImport(UIKit)
  import UIKit
#endif

/// Standard article card: thumbnail, badge, title, snippet, source + timestamp.
/// Uses Liquid Glass material — no opaque custom backgrounds.
struct ArticleCardView: View {
  @Bindable var article: ArticleModel
  let colorHex: String
  @Environment(\.modelContext) private var modelContext

  #if os(macOS)
  @State private var isHovering = false
  #endif

  @AppStorage("openLinksInBackground") private var openInBackground = false
  @AppStorage("markReadOnOpen") private var markReadOnOpen = true

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {

      // MARK: Thumbnail
      thumbnailArea

      // MARK: Text content
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 8) {
          CategoryBadge(label: article.category, colorHex: colorHex)

          if !article.isRead {
            Circle()
              .fill(Color(hex: colorHex))
              .frame(width: 6, height: 6)
              .shadow(color: Color(hex: colorHex).opacity(0.6), radius: 4)
              .accessibilityLabel("Unread")
          }

          Spacer(minLength: 0)
        }

        Text(article.title)
          .font(.headline)
          .lineLimit(3)
          .fixedSize(horizontal: false, vertical: true)
          .lineSpacing(1.2)

        if !article.snippet.isEmpty {
          Text(article.snippet)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(3)
            .lineSpacing(1.1)
        }

        Spacer(minLength: 8)

        // Source row
        HStack(spacing: 6) {
          FaviconImage(urlString: article.link)
          Text(article.source.capitalized)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
          Spacer()
          TimeAgoText(date: article.publishedAt)
        }
      }
      .padding(12)
    }
    // Liquid Glass card — system manages depth, lensing, morphing.
    .glassCard(cornerRadius: 14)
    .opacity(article.isRead ? 0.75 : 1)
    #if os(macOS)
    .scaleEffect(isHovering ? 1.01 : 1)
    .shadow(color: .black.opacity(isHovering ? 0.28 : 0.18), radius: isHovering ? 16 : 10, y: isHovering ? 6 : 4)
    .onHover { hovering in
      isHovering = hovering
    }
    #endif
    // Open article on tap.
    .onTapGesture { openArticle() }
    // Drag-and-drop: drag the article URL.
    .draggable(article.link) {
      ArticleDragPreview(title: article.title, source: article.source)
    }
    // Enhanced context menu.
    .contextMenu {
      Button("Open in Browser") { openArticle() }

      if let url = URL(string: article.link) {
        ShareLink("Share Article", item: url)
      }

      Divider()

      Button(article.isRead ? "Mark as Unread" : "Mark as Read") {
        article.isRead.toggle()
        modelContext.saveOrLog("toggle read from context menu")
      }

      Divider()

      Button("Copy Link") { copyLink() }
      Button("Copy Title") { copyTitle() }
      Button("Copy Title & Link") { copyTitleAndLink() }
    }
  }

  // MARK: - Thumbnail

  private var thumbnailArea: some View {
    Group {
      if let thumb = article.thumbnail, let url = URL(string: ImageURLUpgrader.upgrade(thumb)) {
        CachedAsyncImage(url: url, maxPixel: 1000) {
          placeholderThumb
        }
        .frame(height: 160)
        .frame(maxWidth: .infinity)
        .clipped()
      } else {
        placeholderThumb.frame(height: 100)
      }
    }
    .overlay(alignment: .bottom) {
      LinearGradient(
        colors: [
          .clear,
          Color.black.opacity(0.25)
        ],
        startPoint: .top,
        endPoint: .bottom
      )
      .frame(height: 80)
      .opacity(article.thumbnail == nil ? 0 : 1)
    }
  }

  private var placeholderThumb: some View {
    Rectangle()
      .fill(.secondary.opacity(0.1))
      .overlay(
        Image(systemName: "newspaper")
          .font(.title2)
          .foregroundStyle(.tertiary)
      )
  }

  // MARK: - Helpers

  private func openArticle() {
    if markReadOnOpen {
      article.isRead = true
      // BUG_REPORT: Persist the "Read" state immediately to avoid data loss.
      modelContext.saveOrLog("mark read on open")
    }

    if let url = URL(string: article.link) {
      #if os(macOS)
        // BUG_REPORT: Respect openLinksInBackground preference
        if openInBackground {
          let config = NSWorkspace.OpenConfiguration()
          config.activates = false
          NSWorkspace.shared.open(url, configuration: config)
        } else {
          NSWorkspace.shared.open(url)
        }
      #else
        UIApplication.shared.open(url)
      #endif
    }
  }

  private func copyLink() {
    #if os(macOS)
      NSPasteboard.general.clearContents()
      NSPasteboard.general.setString(article.link, forType: .string)
    #else
      UIPasteboard.general.string = article.link
    #endif
  }

  private func copyTitle() {
    #if os(macOS)
      NSPasteboard.general.clearContents()
      NSPasteboard.general.setString(article.title, forType: .string)
    #else
      UIPasteboard.general.string = article.title
    #endif
  }

  private func copyTitleAndLink() {
    #if os(macOS)
      NSPasteboard.general.clearContents()
      NSPasteboard.general.setString("\(article.title)\n\(article.link)", forType: .string)
    #else
      UIPasteboard.general.string = "\(article.title)\n\(article.link)"
    #endif
  }
}

// MARK: - Drag Preview

/// Lightweight preview shown while dragging an article card.
struct ArticleDragPreview: View {
  let title: String
  let source: String

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.caption.bold())
        .lineLimit(2)
      Text(source.capitalized)
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .padding(8)
    .frame(width: 200)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
  }
}
