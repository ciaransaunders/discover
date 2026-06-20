import Foundation

/// Resolves which body source the Reader should render, in priority order (cluster A1):
/// `content` (full RSS body) → `snippet` → empty state.
///
/// Pure value type with no SwiftUI / SwiftData dependency, so it is trivially testable
/// (`ReaderBodyResolverTests`). It does **not** itself strip HTML — the `.content` case
/// carries raw HTML that `HTMLStripper.paragraphs(_:)` renders; the `.snippet` case is
/// already plain text.
enum ReaderBody: Equatable, Sendable {
    /// Full article HTML from `ArticleModel.content`.
    case content(String)
    /// Truncated plain-text snippet.
    case snippet(String)
    /// Neither a body nor a snippet is available.
    case empty
}

enum ReaderBodyResolver {

    /// Picks the highest-priority non-empty body source.
    ///
    /// Whitespace-only values are treated as absent so we never present a blank body when a
    /// usable snippet exists.
    static func resolve(content: String?, snippet: String) -> ReaderBody {
        if let content, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .content(content)
        }
        if !snippet.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .snippet(snippet)
        }
        return .empty
    }
}

/// View-model seam for the Reader (cluster A1). Kept intentionally thin: the Reader is a
/// read-only presentation over an `ArticleModel`, so the only stateful concern is computing
/// the rendered paragraphs from the resolved body.
@MainActor
struct ReaderViewModel {

    let article: ArticleModel

    /// The resolved body source for this article.
    var body: ReaderBody {
        ReaderBodyResolver.resolve(content: article.content, snippet: article.snippet)
    }

    /// The paragraphs to render in the Reader's scroll view.
    ///
    /// - `.content` → HTML split into readable paragraphs (no WKWebView).
    /// - `.snippet` → the single plain-text snippet.
    /// - `.empty`   → no paragraphs (the view shows its empty state instead).
    var paragraphs: [String] {
        switch body {
        case .content(let html): return HTMLStripper.paragraphs(html)
        case .snippet(let text): return [text]
        case .empty:             return []
        }
    }

    /// Whether the Reader has any body text at all (used to choose between body and empty state).
    var hasBody: Bool { !paragraphs.isEmpty }
}
