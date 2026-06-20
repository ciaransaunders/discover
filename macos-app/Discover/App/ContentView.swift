import SwiftUI
import SwiftData

/// Root view.  Uses `NavigationSplitView` on macOS and iPad so the
/// category sidebar and article grid sit side-by-side naturally.
/// On iPhone, uses a `TabView` with category tabs for compact navigation.
struct ContentView: View {

    @Environment(\.modelContext) private var modelContext

    /// Cluster F2 — the selection this window opens on. Each `WindowGroup(for:)` window passes its
    /// own value so windows are independent; `nil` (or the default) opens on `.all`.
    let launchSelection: SidebarSelection?

    @State private var selection: SidebarSelection

    init(launchSelection: SidebarSelection? = nil) {
        self.launchSelection = launchSelection
        _selection = State(initialValue: launchSelection ?? .all)
    }

    /// Keyboard navigation / selected-article state (cluster B1). Owned here and injected via
    /// `.environment` so every `ArticleListView` (and its cards) shares one selection.
    @State private var navState = NavigationStateModel()

    /// App-lifetime background refresh scheduler (cluster E2), shared across all windows and owned by
    /// `DiscoverApp` (injected via `.environment`). Started from the top-level `.task` below;
    /// `start(context:)` is restart-safe, so each window re-arms the single shared loop rather than
    /// creating its own.
    @Environment(RefreshScheduler.self) private var refreshScheduler
    @State private var setupErrorMessage: String?

    /// Cluster F2 — live category/folder slugs, used to resolve a restored window selection that may
    /// reference a since-deleted category/folder back to `.all`.
    @Query private var categories: [CategoryModel]
    @Query private var folders: [FolderModel]

    var body: some View {
        content
            // Cluster B1 — share the selected-article state with the list + cards.
            .environment(navState)
            // Single app-lifetime refresh loop, owned here (not in the article list).
            // Seed defaults first so feeds exist before the scheduler's initial fetch.
            .task {
                do {
                    try DefaultFeedsSeeder.seedIfNeeded(context: modelContext)
                } catch {
                    setupErrorMessage = error.localizedDescription
                }
                // Cluster F2 — drop a restored selection that points at a deleted category/folder.
                selection = selection.resolved(
                    availableCategorySlugs: Set(categories.map(\.slug)),
                    availableFolderSlugs: Set(folders.map(\.slug))
                )
                refreshScheduler.start(context: modelContext)
            }
            .alert("Setup failed", isPresented: Binding(
                get: { setupErrorMessage != nil },
                set: { if !$0 { setupErrorMessage = nil } }
            )) {
                Button("OK") { setupErrorMessage = nil }
            } message: {
                Text(setupErrorMessage ?? "")
            }
    }

    @ViewBuilder
    private var content: some View {
        #if os(macOS)
        NavigationSplitView {
            CategorySidebarView(selection: $selection)
        } detail: {
            ArticleListView(selection: selection, selectionBinding: $selection)
                // Force the detail column to rebuild its dynamic @Query when the selection
                // changes (the predicate is built in init, not derived reactively).
                .id(selection)
        }
        #else
        iOSLayout
        #endif
    }

    // MARK: - iOS Layout

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var iOSLayout: some View {
        Group {
            if horizontalSizeClass == .regular {
                // iPad: use NavigationSplitView (sidebar + detail)
                NavigationSplitView {
                    CategorySidebarView(selection: $selection)
                } detail: {
                    ArticleListView(selection: selection, selectionBinding: $selection)
                        .id(selection)
                }
            } else {
                // iPhone: use TabView-based navigation
                iOSTabView
            }
        }
    }

    private var iOSTabView: some View {
        TabView {
            Tab("All News", systemImage: "newspaper.fill") {
                NavigationStack {
                    ArticleListView(selection: .all, selectionBinding: $selection)
                }
            }
            Tab("Categories", systemImage: "square.grid.2x2.fill") {
                NavigationStack {
                    // BUG_REPORT: Fixed broken iOS navigation by using navigationDestination instead of conditional rendering.
                    CategorySidebarView(selection: $selection)
                        .navigationDestination(isPresented: Binding(
                            get: { selection != .all },
                            set: { if !$0 { selection = .all } }
                        )) {
                            ArticleListView(selection: selection, selectionBinding: $selection)
                                .id(selection)
                        }
                }
            }
            Tab("Settings", systemImage: "gearshape.fill") {
                NavigationStack {
                    PreferencesView()
                }
            }
        }
    }
    #endif

}
