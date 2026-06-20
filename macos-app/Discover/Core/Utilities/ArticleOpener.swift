import Foundation
import SwiftData

#if canImport(AppKit)
  import AppKit
#endif
#if canImport(UIKit)
  import UIKit
#endif

/// Consolidates the open-in-browser + clipboard logic that was previously duplicated,
/// verbatim, inside both `ArticleCardView` and `HeroCardView` (cluster A1).
///
/// Both cards (and the Reader) route through this single helper. The work that touches the
/// store (`markReadOnOpen`) and the system (browser/pasteboard) is `@MainActor`-isolated.
///
/// ## Testability
/// `openURL` is dispatched through `OpenStrategy`, an injectable seam. Production uses
/// `OpenStrategy.system`, which honours the `openInBackground` flag via the platform APIs.
/// Tests inject a recording strategy to assert the requested `(url, background)` config
/// without launching a browser.
@MainActor
enum ArticleOpener {

    /// How a URL is opened. Injectable so tests can assert the requested configuration
    /// instead of actually launching the system browser.
    struct OpenStrategy: Sendable {
        /// Called with the resolved URL and whether the open was requested in the background.
        let open: @MainActor @Sendable (_ url: URL, _ background: Bool) -> Void

        /// Production strategy: opens via `NSWorkspace` / `UIApplication`, honouring `background`.
        static let system = OpenStrategy { url, background in
            #if canImport(AppKit)
                if background {
                    let config = NSWorkspace.OpenConfiguration()
                    config.activates = false
                    NSWorkspace.shared.open(url, configuration: config)
                } else {
                    NSWorkspace.shared.open(url)
                }
            #elseif canImport(UIKit)
                UIApplication.shared.open(url)
            #endif
        }
    }

    // MARK: - Opening

    /// Opens `article` in the external browser, optionally marking it read first.
    ///
    /// - Parameters:
    ///   - markRead: when `true`, sets `isRead` and persists before opening (honours the
    ///     `markReadOnOpen` preference at the call site).
    ///   - inBackground: when `true`, requests a background open (honours `openLinksInBackground`).
    ///   - context: the SwiftData context used to persist the read flag.
    ///   - strategy: the open seam (defaults to the system browser).
    static func openInBrowser(
        _ article: ArticleModel,
        markRead: Bool,
        inBackground: Bool,
        context: ModelContext?,
        strategy: OpenStrategy = .system
    ) {
        if markRead, !article.isRead {
            article.isRead = true
            context?.saveOrLog("mark read on open (ArticleOpener)")
        }
        guard let url = URL(string: article.link) else { return }
        strategy.open(url, inBackground)
    }

    // MARK: - Read state

    /// Toggles the article's read flag and persists it.
    static func toggleRead(_ article: ArticleModel, context: ModelContext?) {
        article.isRead.toggle()
        context?.saveOrLog("toggle read (ArticleOpener)")
    }

    /// Marks the article read (idempotent) and persists if it changed.
    static func markRead(_ article: ArticleModel, context: ModelContext?) {
        guard !article.isRead else { return }
        article.isRead = true
        context?.saveOrLog("mark read (ArticleOpener)")
    }

    // MARK: - Clipboard

    static func copyLink(_ article: ArticleModel) { copy(article.link) }
    static func copyTitle(_ article: ArticleModel) { copy(article.title) }
    static func copyTitleAndLink(_ article: ArticleModel) { copy("\(article.title)\n\(article.link)") }

    private static func copy(_ string: String) {
        #if canImport(AppKit)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(string, forType: .string)
        #elseif canImport(UIKit)
            UIPasteboard.general.string = string
        #endif
    }
}
