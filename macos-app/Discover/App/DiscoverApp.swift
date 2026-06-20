import SwiftUI
import SwiftData

/// App entry point.  The SwiftData `ModelContainer` is created once here and
/// injected into the environment so every child view shares the same store.
@main
struct DiscoverApp: App {

    private let modelContainer: ModelContainer
    @State private var modelInitError: String?

    init() {
        let (container, errorMessage) = Self.makeModelContainer()
        self.modelContainer = container
        _modelInitError = State(initialValue: errorMessage)
    }

    #if os(macOS)
    @State private var showPreferences = false
    #endif

    var body: some Scene {
        WindowGroup {
            #if os(macOS)
            ContentView()
                .frame(minWidth: 900, minHeight: 600)
                .sheet(isPresented: $showPreferences) {
                    PreferencesView()
                }
                .alert("Data Store Issue", isPresented: Binding(
                    get: { modelInitError != nil },
                    set: { if !$0 { modelInitError = nil } }
                )) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(modelInitError ?? "")
                }
            #else
            ContentView()
            #endif
        }
        .modelContainer(modelContainer)
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .commands {
            // ⌘R — Refresh all feeds
            CommandGroup(after: .toolbar) {
                Button("Refresh Feeds") {
                    NotificationCenter.default.post(name: .refreshFeeds, object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("Force Refresh All") {
                    NotificationCenter.default.post(name: .forceRefreshFeeds, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }

            // ⌘, — Preferences
            CommandGroup(replacing: .appSettings) {
                Button("Preferences…") {
                    showPreferences = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
        #endif
    }
}

// MARK: - Notification names for menu commands

extension Notification.Name {
    static let refreshFeeds      = Notification.Name("refreshFeeds")
    static let forceRefreshFeeds = Notification.Name("forceRefreshFeeds")
}

// MARK: - SwiftData container bootstrapping

extension DiscoverApp {
    private static func makeModelContainer() -> (ModelContainer, String?) {
        let schema = Schema([
            ArticleModel.self,
            FeedModel.self,
            CategoryModel.self,
        ])

        // Prefer persistent storage, but fall back to in-memory if the store cannot be opened
        // (e.g. permissions, corruption, schema mismatch). Avoid crashing on first launch.
        let diskConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return (try ModelContainer(for: schema, configurations: [diskConfig]), nil)
        } catch {
            let errorMessage = "Couldn't open the on-disk database. Discover will run using in-memory storage for this session.\n\n\(error)"
            let memConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return (try ModelContainer(for: schema, configurations: [memConfig]), errorMessage)
            } catch {
                fatalError("SwiftData container failed to initialise (even in-memory): \(error)")
            }
        }
    }
}
