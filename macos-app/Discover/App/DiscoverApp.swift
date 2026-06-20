import SwiftUI
import SwiftData

/// App entry point.  The SwiftData `ModelContainer` is created once here and
/// injected into the environment so every child view shares the same store.
@main
struct DiscoverApp: App {

    private let modelContainer: ModelContainer
    @State private var modelInitError: String?

    /// Cluster A2/A3 — the Reader typography theme + explicit app appearance, created once and
    /// injected via `.environment` so every view (incl. detached sheets) shares one instance.
    @State private var theme = ReaderThemeManager()

    #if os(macOS)
    /// Cluster F3 — hosts AppleScript read-only scriptability (`unread count` / `article count`).
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    init() {
        let (container, errorMessage) = Self.makeModelContainer()
        self.modelContainer = container
        _modelInitError = State(initialValue: errorMessage)
        #if os(macOS)
        // Cluster F3 — give the scripting layer a reference to the shared container for read-only
        // counts. Set here (not in the adaptor) because the container is created in this init.
        AppDelegate.sharedModelContainer = container
        #endif
    }

    #if os(macOS)
    /// Cluster F2 — used by the ⌘N "New Window" command to open an independent window.
    @Environment(\.openWindow) private var openWindow
    #endif

    var body: some Scene {
        #if os(macOS)
        // Cluster F2 — a value-presenting WindowGroup so each window carries its own
        // `SidebarSelection` and is fully independent. The single injected `ModelContainer` is shared
        // across every window, so live `@Query` reads stay consistent everywhere.
        WindowGroup(for: SidebarSelection.self) { $selection in
            ContentView(launchSelection: selection)
                .frame(minWidth: 900, minHeight: 600)
                .alert("Data Store Issue", isPresented: Binding(
                    get: { modelInitError != nil },
                    set: { if !$0 { modelInitError = nil } }
                )) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(modelInitError ?? "")
                }
                // Inject the shared theme; apply the resolved (dark-only) appearance at the
                // content root so sheets inherit it (cluster A3).
                .environment(theme)
                .preferredColorScheme(theme.resolvedColorScheme)
        }
        .modelContainer(modelContainer)
        // OQ-9: keep the hidden title bar — multi-window does not change the window style.
        .windowStyle(.hiddenTitleBar)
        .commands {
            // ⌘N — open a new, independent window (cluster F2). Replaces the default New Item.
            CommandGroup(replacing: .newItem) {
                Button("New Window") {
                    openWindow(value: SidebarSelection.all)
                }
                .keyboardShortcut("n", modifiers: .command)
            }

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
        }

        // Cluster F2 — preferences as a dedicated Settings scene (⌘, opens it). This avoids a single
        // app-level `@State` sheet that does not fit multi-window, while keeping the existing
        // PreferencesView and the standard ⌘, shortcut working. Theme injected so it matches.
        Settings {
            PreferencesView()
                .environment(theme)
                .preferredColorScheme(theme.resolvedColorScheme)
        }
        #else
        WindowGroup {
            ContentView()
                .environment(theme)
                .preferredColorScheme(theme.resolvedColorScheme)
        }
        .modelContainer(modelContainer)
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
        // Build from the latest versioned schema and run the explicit migration plan so existing
        // on-disk stores migrate (lightweight) rather than being discarded. See `DiscoverSchema`.
        let schema = Schema(versionedSchema: DiscoverCurrentSchema.self)

        // Prefer persistent storage, but fall back to in-memory if the store cannot be opened
        // (e.g. permissions, corruption, unmigratable schema mismatch). Avoid crashing on first launch.
        let diskConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return (try ModelContainer(
                for: schema,
                migrationPlan: DiscoverMigrationPlan.self,
                configurations: [diskConfig]
            ), nil)
        } catch {
            let errorMessage = "Couldn't open the on-disk database. Discover will run using in-memory storage for this session.\n\n\(error)"
            let memConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return (try ModelContainer(
                    for: schema,
                    migrationPlan: DiscoverMigrationPlan.self,
                    configurations: [memConfig]
                ), errorMessage)
            } catch {
                fatalError("SwiftData container failed to initialise (even in-memory): \(error)")
            }
        }
    }
}
