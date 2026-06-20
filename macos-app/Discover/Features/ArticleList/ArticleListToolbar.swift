import SwiftUI

#if os(macOS)
/// The identified, user-customisable toolbar for `ArticleListView` (cluster F1).
///
/// Replaces the inline `.toolbar { ToolbarItemGroup … }` with `.toolbar(id:)` + identified
/// `ToolbarItem(id:placement:showsByDefault:)` so macOS can offer the system "Customize Toolbar…"
/// panel and remember which items the user keeps. Each item is a small closure-driven control so the
/// view keeps ownership of state and actions — the toolbar is pure layout.
///
/// OQ-9: the window keeps `.windowStyle(.hiddenTitleBar)`. With a hidden title bar macOS does not
/// expose the "Customize Toolbar…" menu item, so customisation degrades to the fixed default set
/// (the items still organise correctly and the view options still work). Switching to `.titleBar`
/// is **not** done here — that is the accepted known limitation recorded in OQ-9.
///
/// NOTE: this is intentionally a value type returning `CustomizableToolbarContent`; `ArticleListView`
/// applies it via `.toolbar(id: "articleList") { ArticleListToolbar(…) }`.
struct ArticleListToolbar: CustomizableToolbarContent {

    // MARK: - View options (bound to the view's @AppStorage)
    @Binding var sortOrder: ArticleSortOrder
    @Binding var density: ArticleListDensity
    @Binding var hideRead: Bool

    // MARK: - Refresh state
    let isRefreshing: Bool
    let lastRefreshed: Date?
    let canMarkAllRead: Bool

    // MARK: - Actions
    let onRefresh: () -> Void
    let onForceRefresh: () -> Void
    let onMarkAllRead: () -> Void
    let onOpenFeeds: () -> Void

    // MARK: - Body

    var body: some CustomizableToolbarContent {
        // Refresh — shown by default.
        ToolbarItem(id: "refresh", placement: .primaryAction, showsByDefault: true) {
            Button(action: onRefresh) {
                if isRefreshing {
                    ProgressView().controlSize(.small)
                } else {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
            .disabled(isRefreshing)
            .help("Refresh all feeds (⌘R)")
        }

        // Force refresh — opt-in (hidden by default; available in Customize Toolbar).
        ToolbarItem(id: "forceRefresh", placement: .primaryAction, showsByDefault: false) {
            Button(action: onForceRefresh) {
                Label("Force Refresh", systemImage: "arrow.clockwise.circle")
            }
            .disabled(isRefreshing)
            .help("Force refresh all feeds, ignoring caches (⌘⇧R)")
        }

        // Mark all read — shown by default.
        ToolbarItem(id: "markAllRead", placement: .primaryAction, showsByDefault: true) {
            Button(action: onMarkAllRead) {
                Label("Mark All Read", systemImage: "checkmark.circle")
            }
            .disabled(!canMarkAllRead)
            .help("Mark every visible article as read")
        }

        // Hide-read quick toggle — shown by default.
        ToolbarItem(id: "hideRead", placement: .primaryAction, showsByDefault: true) {
            Button {
                hideRead.toggle()
            } label: {
                Label(
                    hideRead ? "Show Read" : "Hide Read",
                    systemImage: hideRead ? "eye.slash.fill" : "eye.slash"
                )
            }
            .help(hideRead ? "Show read articles" : "Hide read articles")
        }

        // View density menu (NEW, cluster F1) — shown by default.
        ToolbarItem(id: "density", placement: .primaryAction, showsByDefault: true) {
            Menu {
                Picker("Density", selection: $density) {
                    ForEach(ArticleListDensity.allCases) { option in
                        Label(option.label, systemImage: option.systemImage).tag(option)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Label("View Density", systemImage: "rectangle.grid.1x2")
            }
            .help("Change how many columns the grid uses")
        }

        // Sort menu (NEW, cluster F1) — shown by default.
        ToolbarItem(id: "sort", placement: .primaryAction, showsByDefault: true) {
            Menu {
                Picker("Sort", selection: $sortOrder) {
                    ForEach(ArticleSortOrder.allCases) { order in
                        Label(order.label, systemImage: order.systemImage).tag(order)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }
            .help("Change the article sort order")
        }

        // Feed manager — shown by default.
        ToolbarItem(id: "feeds", placement: .primaryAction, showsByDefault: true) {
            Button(action: onOpenFeeds) {
                Label("Feeds", systemImage: "dot.radiowaves.up.forward")
            }
            .help("Add or manage feeds")
        }

        // Last-refreshed timestamp — status placement, opt-in.
        ToolbarItem(id: "status", placement: .status, showsByDefault: true) {
            if let lastRefreshed {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle")
                        .font(.caption2)
                    TimeAgoText(date: lastRefreshed)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - macOS modifier wrapper

/// Applies the identified, customisable `ArticleListToolbar` via `.toolbar(id:)` (cluster F1).
/// Wrapping in a `ViewModifier` lets `ArticleListView` swap toolbars by platform without an inline
/// `#if` in the body builder.
struct MacArticleToolbarModifier: ViewModifier {
    @Binding var sortOrder: ArticleSortOrder
    @Binding var density: ArticleListDensity
    @Binding var hideRead: Bool
    let isRefreshing: Bool
    let lastRefreshed: Date?
    let canMarkAllRead: Bool
    let onRefresh: () -> Void
    let onForceRefresh: () -> Void
    let onMarkAllRead: () -> Void
    let onOpenFeeds: () -> Void

    func body(content: Content) -> some View {
        // OQ-9: `.toolbar(id:)` enables system toolbar customisation; with `.hiddenTitleBar` the
        // "Customize Toolbar…" menu item is unavailable, so this degrades to the default item set.
        content.toolbar(id: "articleList") {
            ArticleListToolbar(
                sortOrder: $sortOrder,
                density: $density,
                hideRead: $hideRead,
                isRefreshing: isRefreshing,
                lastRefreshed: lastRefreshed,
                canMarkAllRead: canMarkAllRead,
                onRefresh: onRefresh,
                onForceRefresh: onForceRefresh,
                onMarkAllRead: onMarkAllRead,
                onOpenFeeds: onOpenFeeds
            )
        }
    }
}
#endif

// MARK: - iOS inline toolbar (keeps the mobile branches valid)

#if os(iOS)
/// The original inline toolbar for iOS (no `.toolbar(id:)` customisation on iOS). Preserves the
/// pre-F1 button set so the iPhone/iPad branches keep compiling and behaving identically.
struct InlineArticleToolbarModifier: ViewModifier {
    @Binding var hideRead: Bool
    let isRefreshing: Bool
    let canMarkAllRead: Bool
    let onRefresh: () -> Void
    let onMarkAllRead: () -> Void
    let onOpenFeeds: () -> Void

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    hideRead.toggle()
                } label: {
                    Label(
                        hideRead ? "Show Read" : "Hide Read",
                        systemImage: hideRead ? "eye.slash.fill" : "eye.slash"
                    )
                }

                Button(action: onMarkAllRead) {
                    Label("Mark All Read", systemImage: "checkmark.circle")
                }
                .disabled(!canMarkAllRead)

                Button(action: onOpenFeeds) {
                    Label("Feeds", systemImage: "dot.radiowaves.up.forward")
                }

                Button(action: onRefresh) {
                    if isRefreshing {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(isRefreshing)
            }
        }
    }
}
#endif
