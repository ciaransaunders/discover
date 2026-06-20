import Foundation
import Observation

/// Owns the "selected article" concept the app previously lacked (cluster B1).
///
/// Selection is stored as the **stable djb2 `ArticleModel.id`** (a `String?`), *not* an index or a
/// model reference, so it survives list re-ordering, re-`@Query`, and view rebuilds. The ordered list
/// that gives the selection meaning is always the caller's `displayedArticles` (the single source of
/// truth for order/filter) — this model never holds its own copy of the articles, only the id.
///
/// All stepping logic is pure (`next`/`previous`/`clamp` + absent-id reset) so it is unit-testable
/// without any SwiftUI/SwiftData state. `ContentView` owns one instance and injects it via
/// `.environment`; `ArticleListView` resolves the selected article by id each render.
@MainActor
@Observable
final class NavigationStateModel {

    /// The id of the currently selected article, or `nil` when nothing is selected.
    var selectedArticleID: String?

    init(selectedArticleID: String? = nil) {
        self.selectedArticleID = selectedArticleID
    }

    // MARK: - Reconciliation

    /// Reconciles `selectedArticleID` against the current ordered ids.
    ///
    /// If the selected id is no longer present (article purged, filtered out, search applied), the
    /// selection resets to `nil`. Called each render from `ArticleListView` so the selection can never
    /// dangle on an article that is not on screen. Pure & idempotent.
    func reconcile(orderedIDs: [String]) {
        guard let current = selectedArticleID else { return }
        if !orderedIDs.contains(current) {
            selectedArticleID = nil
        }
    }

    // MARK: - Article stepping (pure)

    /// Selects the next article in `orderedIDs` (clamped at the end).
    ///
    /// - With no current selection, selects the first article.
    /// - At the last article, stays put (clamp, per FEATURE_PLAN OQ-15).
    /// - With an empty list, selection becomes/stays `nil`.
    func selectNext(in orderedIDs: [String]) {
        selectedArticleID = Self.steppedID(from: selectedArticleID, in: orderedIDs, by: +1)
    }

    /// Selects the previous article in `orderedIDs` (clamped at the start).
    ///
    /// - With no current selection, selects the first article.
    /// - At the first article, stays put (clamp).
    /// - With an empty list, selection becomes/stays `nil`.
    func selectPrevious(in orderedIDs: [String]) {
        selectedArticleID = Self.steppedID(from: selectedArticleID, in: orderedIDs, by: -1)
    }

    /// Pure stepping core: the id `step` positions from `current` within `ids`, clamped to bounds.
    ///
    /// Empty list → `nil`. Absent/`nil` current → the first id. Otherwise the neighbour at the
    /// clamped index. Exposed `static` so tests exercise the index math directly.
    static func steppedID(from current: String?, in ids: [String], by step: Int) -> String? {
        guard !ids.isEmpty else { return nil }
        guard let current, let index = ids.firstIndex(of: current) else {
            // No (or stale) selection: land on the first article.
            return ids.first
        }
        let target = min(max(index + step, 0), ids.count - 1)
        return ids[target]
    }

    // MARK: - Selection helpers

    /// Clears the current selection.
    func clear() {
        selectedArticleID = nil
    }
}

// MARK: - Category cycling (pure, Sendable)

/// Pure helpers for cycling the sidebar `SidebarSelection` across the persisted category slugs
/// (cluster B2: Tab / `]` / `[`).
///
/// The cycle is the ordered category slugs with `.all` as the wrap point at *both* ends:
///
///     .all → category[0] → category[1] → … → category[n-1] → .all → category[0] → …
///
/// Smart-feed and folder selections are not part of the ring; cycling forward from one jumps to the
/// first category, cycling backward jumps to the last (graceful, never a no-op as long as categories
/// exist). With no categories at all, every result is `.all`.
enum CategoryCycler {

    /// The next selection after `current`, given the ordered category `slugs`.
    static func next(after current: SidebarSelection, slugs: [String]) -> SidebarSelection {
        guard !slugs.isEmpty else { return .all }

        switch current {
        case .all:
            // Wrap point → first category.
            return .category(slugs[0])
        case .category(let slug):
            guard let index = slugs.firstIndex(of: slug) else {
                // Unknown slug (e.g. deleted category) → start the ring over.
                return .category(slugs[0])
            }
            let nextIndex = index + 1
            return nextIndex < slugs.count ? .category(slugs[nextIndex]) : .all
        default:
            // Smart feeds / folders are outside the ring → enter at the first category.
            return .category(slugs[0])
        }
    }

    /// The previous selection before `current`, given the ordered category `slugs`.
    static func previous(before current: SidebarSelection, slugs: [String]) -> SidebarSelection {
        guard !slugs.isEmpty else { return .all }

        switch current {
        case .all:
            // Wrap point → last category.
            return .category(slugs[slugs.count - 1])
        case .category(let slug):
            guard let index = slugs.firstIndex(of: slug) else {
                // Unknown slug → wrap to the last category.
                return .category(slugs[slugs.count - 1])
            }
            let prevIndex = index - 1
            return prevIndex >= 0 ? .category(slugs[prevIndex]) : .all
        default:
            // Smart feeds / folders are outside the ring → enter at the last category.
            return .category(slugs[slugs.count - 1])
        }
    }
}
