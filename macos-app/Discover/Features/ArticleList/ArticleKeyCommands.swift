import Foundation

#if os(macOS)
import SwiftUI

/// A single, platform-agnostic navigation command produced by a key press in the article list.
///
/// This is the *intent* layer (cluster B2): the focusable list region's `.onKeyPress` router maps a
/// raw `(KeyEquivalent, EventModifiers)` into one of these via the pure `ArticleKeyCommands.command(for:modifiers:)`
/// mapper, then `ArticleListView` interprets it against the current selection / `displayedArticles`.
/// Keeping this an enum (not closures) makes the whole key map unit-testable with zero SwiftUI/UI state.
///
/// `nil` (the absence of a command) means *not ours* — the router returns `.ignored` so text fields,
/// buttons, and default activation keep working.
enum ArticleKeyCommand: Equatable, Sendable {
    /// Select the next article (NetNewsWire `n`/`j`). Clamps at the end of the list.
    case nextArticle
    /// Select the previous article (NetNewsWire `p`/`k`). Clamps at the start of the list.
    case previousArticle
    /// Open the selected article — same path as a card tap (Reader if `tapOpensReader`, else browser).
    case openSelection
    /// Toggle the selected article's read state (`r`).
    case toggleRead
    /// Mark the selected article read and advance to the next (`m`).
    case markReadAndAdvance
    /// Mark the selected article unread (`u`).
    case markUnread
    /// Advance to the next category (Tab / `]`).
    case nextCategory
    /// Go to the previous category (`[`).
    case previousCategory
    /// Clear the current selection (and let the caller also dismiss search) — Esc.
    case clearSelection
}

/// Pure, stateless key → command mapper for the article list (cluster B2).
///
/// NetNewsWire-style single keys are *not* registered as menu `.keyboardShortcut`s (that would
/// capture single letters globally and steal them from text fields); instead the focusable list
/// region routes raw key presses through this function. Any key carrying the `.command` modifier is
/// deliberately **not** ours (returns `nil`) so app/menu command shortcuts (⌘R, ⌘N, …) win.
enum ArticleKeyCommands {

    /// Maps a key + active modifiers to a navigation command, or `nil` if the list does not own it.
    ///
    /// - Parameters:
    ///   - key: the pressed `KeyEquivalent` (lower-cased characters as SwiftUI reports them).
    ///   - modifiers: the active `EventModifiers` for the press.
    /// - Returns: the `ArticleKeyCommand` to perform, or `nil` to ignore (router returns `.ignored`).
    static func command(for key: KeyEquivalent, modifiers: EventModifiers) -> ArticleKeyCommand? {
        // Never claim Command-modified keys — those belong to menu/app shortcuts (⌘R refresh, etc).
        if modifiers.contains(.command) { return nil }

        switch key {
        case "n", "j":
            return .nextArticle
        case "p", "k":
            return .previousArticle
        case .space, .`return`:
            return .openSelection
        case "r":
            return .toggleRead
        case "m":
            return .markReadAndAdvance
        case "u":
            return .markUnread
        case .tab, "]":
            return .nextCategory
        case "[":
            return .previousCategory
        case .escape:
            return .clearSelection
        default:
            return nil
        }
    }
}
#endif
