import SwiftUI
import SwiftData

/// In-app plain-text Reader (cluster A1).
///
/// Presented as a `.sheet` when a card is tapped (default; reversible via
/// `@AppStorage("tapOpensReader")`). Renders the article body as readable paragraphs via
/// `HTMLStripper.paragraphs(_:)` — **no WKWebView** (honours dark-only + zero-dependency).
/// An explicit "Open in Browser" affordance always remains.
struct ReaderView: View {

    @Bindable var article: ArticleModel
    let colorHex: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ReaderThemeManager.self) private var theme

    @AppStorage("markReadOnOpen") private var markReadOnOpen = true
    @AppStorage("openLinksInBackground") private var openInBackground = false

    private var viewModel: ReaderViewModel { ReaderViewModel(article: article) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    heroImage
                    header
                    Divider()
                    bodyContent
                }
                .frame(maxWidth: theme.lineWidth.maxContentWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
            }
            .navigationTitle("")
            #if os(macOS)
            .toolbar { toolbarContent }
            #else
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            #endif
        }
        .frame(minWidth: 480, minHeight: 480)
        .task { markReadOnOpenIfNeeded() }
    }

    // MARK: - Hero image

    @ViewBuilder
    private var heroImage: some View {
        if let thumb = article.thumbnail,
           let url = URL(string: ImageURLUpgrader.upgrade(thumb)) {
            CachedAsyncImage(url: url, maxPixel: 1400) {
                placeholder
            }
            .frame(maxWidth: .infinity)
            .frame(height: 260)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var placeholder: some View {
        Rectangle()
            .fill(.secondary.opacity(0.1))
            .overlay(
                Image(systemName: "newspaper")
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary)
            )
    }

    // MARK: - Header (badge, title, source row)

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            CategoryBadge(label: article.category, colorHex: colorHex)

            Text(article.title)
                .font(theme.titleFont())
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)

            HStack(spacing: 8) {
                FaviconImage(urlString: article.link, size: 18)
                Text(article.source.capitalized)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                TimeAgoText(date: article.publishedAt)
            }
        }
    }

    // MARK: - Body

    @ViewBuilder
    private var bodyContent: some View {
        if viewModel.hasBody {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(viewModel.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                    Text(paragraph)
                        .font(theme.bodyFont())
                        .foregroundStyle(.primary)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }

                openFullArticleButton
                    .padding(.top, 8)
            }
        } else {
            emptyState
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("No preview available")
                .font(theme.bodyFont())
                .foregroundStyle(.secondary)
            Text("This feed didn't include the article text. Open the full article to read it in your browser.")
                .font(.callout)
                .foregroundStyle(.secondary)
            openFullArticleButton
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var openFullArticleButton: some View {
        Button {
            openInBrowser()
        } label: {
            Label("Read Full Article", systemImage: "safari")
        }
        .buttonStyle(.borderedProminent)
        .tint(Color(hex: colorHex))
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        #if os(macOS)
        ToolbarItem(placement: .cancellationAction) {
            Button("Done") { dismiss() }
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                ArticleOpener.toggleRead(article, context: modelContext)
            } label: {
                Label(
                    article.isRead ? "Mark as Unread" : "Mark as Read",
                    systemImage: article.isRead ? "circle" : "circle.fill"
                )
            }

            if let url = URL(string: article.link) {
                ShareLink(item: url) { Label("Share", systemImage: "square.and.arrow.up") }
            }

            Button {
                openInBrowser()
            } label: {
                Label("Open in Browser", systemImage: "safari")
            }
        }
        #else
        ToolbarItem(placement: .cancellationAction) {
            Button("Done") { dismiss() }
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                ArticleOpener.toggleRead(article, context: modelContext)
            } label: {
                Label(
                    article.isRead ? "Mark as Unread" : "Mark as Read",
                    systemImage: article.isRead ? "circle" : "circle.fill"
                )
            }
            if let url = URL(string: article.link) {
                ShareLink(item: url) { Label("Share", systemImage: "square.and.arrow.up") }
            }
            Button {
                openInBrowser()
            } label: {
                Label("Open in Browser", systemImage: "safari")
            }
        }
        #endif
    }

    // MARK: - Actions

    /// Marks the article read on open if the user preference is set (cluster A1).
    private func markReadOnOpenIfNeeded() {
        guard markReadOnOpen else { return }
        ArticleOpener.markRead(article, context: modelContext)
    }

    /// Opens the article in the external browser via the shared opener. Does not re-mark read
    /// (already handled on open); honours the background-open preference.
    private func openInBrowser() {
        ArticleOpener.openInBrowser(
            article,
            markRead: false,
            inBackground: openInBackground,
            context: modelContext
        )
    }
}
