import SwiftUI

/// Full-width hero card displayed as the leading article in the list.
/// Large image on the left, text on the right — mirrors the web `HeroCard.tsx`.
struct HeroCardView: View {
  @Bindable var article: ArticleModel
  let colorHex: String
  /// Cluster B1 — keyboard selection ring. Defaulted so existing call sites keep compiling.
  var isSelected: Bool = false
  @Environment(\.modelContext) private var modelContext

  #if os(macOS)
  @State private var isHovering = false
  #endif

  @AppStorage("openLinksInBackground") private var openInBackground = false
  @AppStorage("markReadOnOpen") private var markReadOnOpen = true
  // Cluster A1 — card tap opens the in-app Reader by default (reversible).
  @AppStorage("tapOpensReader") private var tapOpensReader = true

  @State private var showReader = false

  var body: some View {
    heroLayout
      .frame(maxWidth: .infinity, minHeight: 200, maxHeight: 240)
      .glassCard(cornerRadius: 16)
      // Cluster B1 — keyboard-selection ring in the category accent colour, over the glass.
      .overlay {
        if isSelected {
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(Color(hex: colorHex), lineWidth: 3)
            .accessibilityHidden(true)
        }
      }
      .opacity(article.isRead ? 0.75 : 1)
      #if os(macOS)
      .scaleEffect(isHovering ? 1.01 : 1)
      .shadow(color: .black.opacity(isHovering ? 0.28 : 0.18), radius: isHovering ? 18 : 12, y: isHovering ? 6 : 4)
      .onHover { hovering in
        isHovering = hovering
      }
      #endif
      .onTapGesture { handleTap() }
      // Drag-and-drop: drag the article URL.
      .draggable(article.link) {
        ArticleDragPreview(title: article.title, source: article.source)
      }
      // Enhanced context menu.
      .contextMenu {
        Button("Open in Reader") { showReader = true }
        Button("Open in Browser") { openInBrowser() }

        if let url = URL(string: article.link) {
          ShareLink("Share Article", item: url)
        }

        Divider()

        Button(article.isRead ? "Mark as Unread" : "Mark as Read") {
          ArticleOpener.toggleRead(article, context: modelContext)
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

        Button("Copy Link") { ArticleOpener.copyLink(article) }
        Button("Copy Title") { ArticleOpener.copyTitle(article) }
        Button("Copy Title & Link") { ArticleOpener.copyTitleAndLink(article) }
      }
      .sheet(isPresented: $showReader) {
        ReaderView(article: article, colorHex: colorHex)
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

  /// Card tap: open the in-app Reader (default) or fall back to the browser (cluster A1).
  private func handleTap() {
    if tapOpensReader {
      showReader = true
    } else {
      openInBrowser()
    }
  }

  /// Opens the article in the external browser via the shared `ArticleOpener`.
  private func openInBrowser() {
    ArticleOpener.openInBrowser(
      article,
      markRead: markReadOnOpen,
      inBackground: openInBackground,
      context: modelContext
    )
  }
}
