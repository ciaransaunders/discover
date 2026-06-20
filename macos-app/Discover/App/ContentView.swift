import SwiftUI
import SwiftData

/// Root view.  Uses `NavigationSplitView` on macOS and iPad so the
/// category sidebar and article grid sit side-by-side naturally.
/// On iPhone, uses a `TabView` with category tabs for compact navigation.
struct ContentView: View {

    @Environment(\.modelContext) private var modelContext

    @State private var selection: SidebarSelection = .all

    /// Keyboard navigation / selected-article state (cluster B1). Owned here and injected via
    /// `.environment` so every `ArticleListView` (and its cards) shares one selection.
    @State private var navState = NavigationStateModel()

    /// App-lifetime background refresh scheduler (cluster E2). Owns the single long-lived refresh
    /// loop, started from the top-level `.task` below — replaces the old view-scoped loop in
    /// `ArticleListView`.
    @State private var refreshScheduler = RefreshScheduler(viewModel: ArticleListViewModel())
    @State private var setupErrorMessage: String?

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
