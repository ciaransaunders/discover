import SwiftUI
import SwiftData

/// Root view.  Uses `NavigationSplitView` on macOS and iPad so the
/// category sidebar and article grid sit side-by-side naturally.
/// On iPhone, uses a `TabView` with category tabs for compact navigation.
struct ContentView: View {

    @State private var selectedCategory: String? = nil

    var body: some View {
        #if os(macOS)
        NavigationSplitView {
            CategorySidebarView(selectedCategory: $selectedCategory)
        } detail: {
            ArticleListView(selectedCategory: selectedCategory)
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
                    CategorySidebarView(selectedCategory: $selectedCategory)
                } detail: {
                    ArticleListView(selectedCategory: selectedCategory)
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
                    ArticleListView(selectedCategory: nil)
                }
            }
            Tab("Categories", systemImage: "square.grid.2x2.fill") {
                NavigationStack {
                    // BUG_REPORT: Fixed broken iOS navigation by using navigationDestination instead of conditional rendering.
                    CategorySidebarView(selectedCategory: $selectedCategory)
                        .navigationDestination(isPresented: Binding(
                            get: { selectedCategory != nil },
                            set: { if !$0 { selectedCategory = nil } }
                        )) {
                            if let category = selectedCategory {
                                ArticleListView(selectedCategory: category)
                            }
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
