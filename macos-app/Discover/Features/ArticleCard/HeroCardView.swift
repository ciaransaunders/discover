import SwiftUI

#if canImport(AppKit)
  import AppKit
#endif
#if canImport(UIKit)
  import UIKit
#endif

/// Full-width hero card displayed as the leading article in the list.
/// Large image on the left, text on the right — mirrors the web `HeroCard.tsx`.
struct HeroCardView: View {
  @Bindable var article: ArticleModel
  let colorHex: String
  @Environment(\.modelContext) private var modelContext

  #if os(macOS)
  @State private var isHovering = false
  #endif

  @AppStorage("openLinksInBackground") private var openInBackground = false
  @AppStorage("markReadOnOpen") private var markReadOnOpen = true

  var body: some View {
    heroLayout
      .frame(maxWidth: .infinity, minHeight: 200, maxHeight: 240)
      .glassCard(cornerRadius: 16)
      .opacity(article.isRead ? 0.75 : 1)
      #if os(macOS)
      .scaleEffect(isHovering ? 1.01 : 1)
      .shadow(color: .black.opacity(isHovering ? 0.28 : 0.18), radius: isHovering ? 18 : 12, y: isHovering ? 6 : 4)
      .onHover { hovering in
        isHovering = hovering
      }
      #endif
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

        Button {
          article.isStarred.toggle()
          modelContext.saveOrLog("toggle starred from context menu")
        } label: {
          Label(
            article.isStarred ? "Unstar" : "Star",
            systemImage: article.isStarred ? "star.fill" : "star"
          )
        }

        Divider()

        Button("Copy Link") { copyLink() }
        Button("Copy Title") { copyTitle() }
        Button("Copy Title & Link") { copyTitleAndLink() }
      }
  }

  // MARK: - Layout

  private var heroLayout: some View {
    HStack(spacing: 0) {
      thumbnailArea
        .frame(width: 280)
        .clipped()

      VStack(alignment: .leading, spacing: 10) {
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

          if article.isStarred {
            Image(systemName: "star.fill")
              .font(.caption)
              .foregroundStyle(.yellow)
              .accessibilityLabel("Starred")
          }
        }

        Text(article.title)
          .font(.title3.bold())
          .lineLimit(4)
          .lineSpacing(1.2)

        if !article.snippet.isEmpty {
          Text(article.snippet)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(4)
            .lineSpacing(1.1)
        }

        Spacer()

        HStack(spacing: 6) {
          FaviconImage(urlString: article.link, size: 18)
          Text(article.source.capitalized)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          Spacer()
          TimeAgoText(date: article.publishedAt)
        }
      }
      .padding(18)
    }
  }

  // MARK: - Thumbnail

  private var thumbnailArea: some View {
    Group {
      if let thumb = article.thumbnail, let url = URL(string: ImageURLUpgrader.upgrade(thumb)) {
        CachedAsyncImage(url: url, maxPixel: 900) {
          placeholderThumb
        }
      } else {
        placeholderThumb
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
      .frame(height: 90)
      .opacity(article.thumbnail == nil ? 0 : 1)
    }
  }

  private var placeholderThumb: some View {
    Rectangle()
      .fill(.secondary.opacity(0.12))
      .overlay(
        Image(systemName: "newspaper.fill")
          .font(.largeTitle)
          .foregroundStyle(.tertiary)
      )
  }

  // MARK: - Actions

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
