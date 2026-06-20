#if os(macOS)
import AppKit
import SwiftData

/// Minimal `NSApplicationDelegate` to host AppleScript support (cluster F3).
///
/// The delegate is intentionally thin: it only provides the read-only scriptability surface
/// (`unread count` / `article count`) with a reference to the shared `ModelContainer`. The action
/// verbs (`refresh feeds` / `force refresh feeds`) are `NSScriptCommand` subclasses that post the
/// existing notifications and need no delegate state.
///
/// Installed via `@NSApplicationDelegateAdaptor` in `DiscoverApp`. No new entitlement is required to
/// *be* scriptable; the v1 surface is read-only + notification-posting only (OQ-10), so no
/// `apple-events` entitlement is added.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    /// The shared SwiftData container, set by `DiscoverApp` once it has been created. Read-only
    /// scripting counts run against this. Optional so the delegate is valid before the App body runs.
    static var sharedModelContainer: ModelContainer?

    // MARK: - Scripting key-value access (read-only)
    //
    // AppleScript reads `unread count` / `article count` as properties of the application object.
    // Cocoa Scripting calls the matching KVC getter on the app delegate (wired in the .sdef via the
    // `application` class extension). These are computed, never stored, and perform no writes.

    /// `unread count` — number of unread articles in the shared store. Returns 0 if unavailable.
    @objc var unreadCount: Int {
        ScriptingDataReader.unreadCount(container: Self.sharedModelContainer)
    }

    /// `article count` — total number of articles in the shared store. Returns 0 if unavailable.
    @objc var articleCount: Int {
        ScriptingDataReader.articleCount(container: Self.sharedModelContainer)
    }
}
#endif
