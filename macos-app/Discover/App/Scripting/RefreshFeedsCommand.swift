#if os(macOS)
import AppKit

/// AppleScript `refresh feeds` command (cluster F3).
///
/// A thin bridge: posting the same `.refreshFeeds` notification the ⌘R menu item and the toolbar
/// already post, so the scripting path reuses the existing refresh pipeline rather than duplicating
/// it. No store mutation happens here (OQ-10 — action verbs only post notifications).
///
/// `performDefaultImplementation` is invoked by Cocoa Scripting and is **not** statically isolated to
/// the main actor, so the actual main-actor work is wrapped in `MainActor.assumeIsolated`
/// (NSScriptCommand execution is always delivered on the main thread).
final class RefreshFeedsCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        MainActor.assumeIsolated {
            NotificationCenter.default.post(name: .refreshFeeds, object: nil)
        }
        return nil
    }
}

/// AppleScript `force refresh feeds` command (cluster F3).
///
/// As `RefreshFeedsCommand`, but posts `.forceRefreshFeeds` (the ⌘⇧R path), which fetches everything
/// fresh ignoring the in-flight guard. Read-/notification-only; no direct store writes.
final class ForceRefreshFeedsCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        MainActor.assumeIsolated {
            NotificationCenter.default.post(name: .forceRefreshFeeds, object: nil)
        }
        return nil
    }
}
#endif
