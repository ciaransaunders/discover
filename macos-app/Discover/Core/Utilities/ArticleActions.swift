import Foundation
import SwiftData

/// Thin keyboard-side façade over the read-state operations the cards already perform (cluster B2).
///
/// This exists so the single-key shortcuts (`r` / `m` / `u`) and the card context menus share **one**
/// code path. Opening is *not* re-implemented here — it routes through the existing `ArticleOpener`
/// (the single seam that handles Reader-vs-browser and `markReadOnOpen`); these helpers only cover the
/// read-state verbs that have no extra UI plumbing.
///
/// Every operation persists via `ModelContext.saveOrLog` (no silent `try?`).
@MainActor
enum ArticleActions {

    /// Toggle read ↔ unread (`r`). Delegates to `ArticleOpener.toggleRead` so behaviour is identical
    /// to the context-menu "Mark as Read / Unread".
    static func toggleRead(_ article: ArticleModel, context: ModelContext?) {
        ArticleOpener.toggleRead(article, context: context)
    }

    /// Mark read (idempotent, `m`). Delegates to `ArticleOpener.markRead`; callers advance selection.
    static func markRead(_ article: ArticleModel, context: ModelContext?) {
        ArticleOpener.markRead(article, context: context)
    }

    /// Mark unread (idempotent, `u`). The one verb `ArticleOpener` did not already expose.
    static func markUnread(_ article: ArticleModel, context: ModelContext?) {
        guard article.isRead else { return }
        article.isRead = false
        context?.saveOrLog("mark unread (ArticleActions)")
    }
}
