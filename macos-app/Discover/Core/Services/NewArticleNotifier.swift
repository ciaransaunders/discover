import Foundation
import OSLog

#if canImport(UserNotifications)
  import UserNotifications
#endif

/// Posts an optional local notification summarising newly-fetched articles (cluster E2).
///
/// Constraints (deliberate, per the feature plan):
/// - **No** new entitlement, **no** Info.plist usage string, and we **never** call
///   `requestAuthorization`. Authorization is the user's call, made elsewhere/out of band.
/// - We only post if notifications are *already* authorized.
/// - Off by default, gated behind `@AppStorage("notifyOnNewArticles")`.
///
/// The body-text builder is pure and unit-tested via `notificationBody(forNewCount:)`.
enum NewArticleNotifier {

    /// User-facing notification body for `count` new articles, or `nil` when there's nothing new.
    ///
    /// - `0`  → `nil` (don't post).
    /// - `1`  → `"1 new article"`.
    /// - `n>1`→ `"n new articles"`.
    static func notificationBody(forNewCount count: Int) -> String? {
        guard count > 0 else { return nil }
        return count == 1 ? "1 new article" : "\(count) new articles"
    }

    /// Posts a notification for `count` new articles **iff** the feature is enabled and the app is
    /// already authorized to post. No-op otherwise (including when `count == 0`).
    static func postIfEnabled(newCount count: Int) async {
        guard UserDefaults.standard.bool(forKey: "notifyOnNewArticles") else { return }
        guard let body = notificationBody(forNewCount: count) else { return }

        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        // Only post if the user has already granted authorization elsewhere — we never request it.
        guard settings.authorizationStatus == .authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Discover"
        content.body = body
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        do {
            try await center.add(request)
        } catch {
            Logger.networking.error("Failed to post new-article notification: \(error.localizedDescription, privacy: .public)")
        }
        #endif
    }
}
