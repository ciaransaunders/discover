import Testing

#if os(macOS)
import SwiftUI
@testable import Discover

@Suite("Discover — Article key commands")
struct ArticleKeyCommandsTests {

    // MARK: - Next / previous

    @Test("n and j both map to nextArticle")
    func nextKeys() {
        #expect(ArticleKeyCommands.command(for: "n", modifiers: []) == .nextArticle)
        #expect(ArticleKeyCommands.command(for: "j", modifiers: []) == .nextArticle)
    }

    @Test("p and k both map to previousArticle")
    func previousKeys() {
        #expect(ArticleKeyCommands.command(for: "p", modifiers: []) == .previousArticle)
        #expect(ArticleKeyCommands.command(for: "k", modifiers: []) == .previousArticle)
    }

    // MARK: - Open

    @Test("space and return both open the selection")
    func openKeys() {
        #expect(ArticleKeyCommands.command(for: .space, modifiers: []) == .openSelection)
        #expect(ArticleKeyCommands.command(for: .return, modifiers: []) == .openSelection)
    }

    // MARK: - Read-state verbs

    @Test("r toggles read")
    func toggleReadKey() {
        #expect(ArticleKeyCommands.command(for: "r", modifiers: []) == .toggleRead)
    }

    @Test("m marks read and advances")
    func markReadKey() {
        #expect(ArticleKeyCommands.command(for: "m", modifiers: []) == .markReadAndAdvance)
    }

    @Test("u marks unread")
    func markUnreadKey() {
        #expect(ArticleKeyCommands.command(for: "u", modifiers: []) == .markUnread)
    }

    // MARK: - Category cycling

    @Test("Tab and ] both advance the category")
    func nextCategoryKeys() {
        #expect(ArticleKeyCommands.command(for: .tab, modifiers: []) == .nextCategory)
        #expect(ArticleKeyCommands.command(for: "]", modifiers: []) == .nextCategory)
    }

    @Test("[ goes to the previous category")
    func previousCategoryKey() {
        #expect(ArticleKeyCommands.command(for: "[", modifiers: []) == .previousCategory)
    }

    // MARK: - Escape

    @Test("Escape clears the selection")
    func escapeKey() {
        #expect(ArticleKeyCommands.command(for: .escape, modifiers: []) == .clearSelection)
    }

    // MARK: - Command-modified keys are NOT ours

    @Test("Command-modified keys are unhandled (so menu shortcuts win)")
    func commandModifierIgnored() {
        // ⌘N (new window), ⌘R (refresh), ⌘M (minimise) etc. must NOT be claimed.
        #expect(ArticleKeyCommands.command(for: "n", modifiers: .command) == nil)
        #expect(ArticleKeyCommands.command(for: "r", modifiers: .command) == nil)
        #expect(ArticleKeyCommands.command(for: "m", modifiers: .command) == nil)
        #expect(ArticleKeyCommands.command(for: .return, modifiers: .command) == nil)
        // Even a combination including Command is ignored.
        #expect(ArticleKeyCommands.command(for: "k", modifiers: [.command, .shift]) == nil)
    }

    @Test("non-command modifiers (shift/option) still map nav keys")
    func nonCommandModifiersStillMap() {
        #expect(ArticleKeyCommands.command(for: "n", modifiers: .shift) == .nextArticle)
        #expect(ArticleKeyCommands.command(for: "j", modifiers: .option) == .nextArticle)
    }

    // MARK: - Unowned keys

    @Test("unrelated keys return nil")
    func unownedKeysIgnored() {
        #expect(ArticleKeyCommands.command(for: "x", modifiers: []) == nil)
        #expect(ArticleKeyCommands.command(for: "1", modifiers: []) == nil)
        #expect(ArticleKeyCommands.command(for: .leftArrow, modifiers: []) == nil)
    }
}
#endif
