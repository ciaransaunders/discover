#if os(macOS)
import Foundation
import SwiftData

/// Read-only SwiftData counts exposed to AppleScript (cluster F3, OQ-10 minimal surface).
///
/// Pure, `@MainActor` helpers that run `FetchDescriptor` *counts* against a `ModelContainer` and
/// perform **no writes** (verified by `ScriptingDataReaderTests`). They take the container as a
/// parameter so the same code serves the app delegate (shared container) and the tests (in-memory
/// container). All access is `@MainActor` — callers inside `NSScriptCommand.performDefaultImplementation`
/// (which is not statically main-actor) hop on via `MainActor.assumeIsolated`.
@MainActor
enum ScriptingDataReader {

    /// Total number of articles in the store. `0` when the container is unavailable or the fetch
    /// fails (scripting should degrade quietly, never throw across the AppleScript boundary).
    static func articleCount(container: ModelContainer?) -> Int {
        count(of: ArticleModel.self, predicate: nil, container: container)
    }

    /// Number of unread articles in the store. `0` on any failure (see `articleCount`).
    static func unreadCount(container: ModelContainer?) -> Int {
        count(of: ArticleModel.self, predicate: #Predicate { !$0.isRead }, container: container)
    }

    /// Shared counting helper. Uses `ModelContext.fetchCount` so no model objects are materialised
    /// and nothing is inserted/updated/deleted — the read is side-effect-free.
    private static func count<T: PersistentModel>(
        of type: T.Type,
        predicate: Predicate<T>?,
        container: ModelContainer?
    ) -> Int {
        guard let container else { return 0 }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<T>(predicate: predicate)
        return (try? context.fetchCount(descriptor)) ?? 0
    }
}
#endif
