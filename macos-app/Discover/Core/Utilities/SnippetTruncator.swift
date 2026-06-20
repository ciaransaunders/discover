import Foundation

/// Truncates plain text to a readable snippet length, preferring sentence
/// boundaries — a direct port of `truncateSnippet()` in `lib/fetchFeeds.ts`.
enum SnippetTruncator {

    static let maxLength = 200
    private static let sentenceEnds = CharacterSet(charactersIn: ".!?")
    private static let whitespaceRegex = try? NSRegularExpression(pattern: "\\s+")

    // MARK: - Public API

    /// Returns a cleaned, sentence-aware truncation of `text`.
    static func truncate(_ text: String) -> String {
        // Collapse whitespace first.
        var cleaned = text
        if let regex = whitespaceRegex {
            let r = NSRange(cleaned.startIndex..., in: cleaned)
            cleaned = regex.stringByReplacingMatches(in: cleaned, range: r, withTemplate: " ")
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleaned.count > maxLength else { return cleaned }

        // Look for a sentence boundary within [60 … maxLength+50].
        let windowEnd = min(maxLength + 50, cleaned.count)
        let window = String(cleaned.prefix(windowEnd))
        var idx = window.index(window.startIndex, offsetBy: min(maxLength, window.count) - 1)

        while idx > window.startIndex {
            if let scalar = window[idx].unicodeScalars.first, sentenceEnds.contains(scalar) {
                let candidate = String(window[...idx]).trimmingCharacters(in: .whitespaces)
                if candidate.count >= 60 { return candidate }
            }
            idx = window.index(before: idx)
        }

        // Hard-break at the last word boundary before maxLength.
        let hard = String(cleaned.prefix(maxLength))
        if let lastSpace = hard.lastIndex(of: " ") {
            return String(hard[..<lastSpace]) + "…"
        }
        return hard + "…"
    }
}
