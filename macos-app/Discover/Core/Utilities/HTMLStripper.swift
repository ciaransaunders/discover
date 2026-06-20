import Foundation

/// Removes HTML tags and decodes common HTML entities from a string.
enum HTMLStripper {

    // Compiled once at load time.
    private static let tagRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: "<[^>]+>",
        options: []
    )

    private static let numericEntityRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: "&#(\\d+);",
        options: []
    )

    private static let entityMap: [(String, String)] = [
        ("&amp;",   "&"),  ("&lt;",    "<"),  ("&gt;",    ">"),
        ("&quot;",  "\""), ("&#39;",   "'"),  ("&apos;",  "'"),
        ("&nbsp;",  " "),  ("&ndash;", "–"),  ("&mdash;", "—"),
        ("&hellip;","…"),  ("&lsquo;", "\u{2018}"), ("&rsquo;", "\u{2019}"),
        ("&ldquo;", "\u{201C}"), ("&rdquo;", "\u{201D}"),
    ]

    /// Block-level tags whose boundaries become paragraph breaks in `paragraphs(_:)`.
    /// Matches an opening *or* closing tag (optionally self-closed) for any of these
    /// elements, case-insensitively, plus any attributes.
    private static let blockBreakRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: "</?(?:p|br|div|li|ul|ol|h[1-6]|blockquote|tr|table|section|article|figure|figcaption|pre|hr)\\b[^>]*>",
        options: [.caseInsensitive]
    )

    // MARK: - Public API

    /// Strips all HTML tags, decodes entities, and trims whitespace.
    static func strip(_ html: String) -> String {
        guard !html.isEmpty else { return html }
        let range = NSRange(html.startIndex..., in: html)
        var text = tagRegex?.stringByReplacingMatches(in: html, range: range, withTemplate: "") ?? html
        text = decodeEntities(text)
        // Collapse repeated whitespace.
        while text.contains("  ") { text = text.replacingOccurrences(of: "  ", with: " ") }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Splits RSS/Atom HTML into readable paragraphs for the in-app Reader (cluster A1).
    ///
    /// Block-level tags (`<p>`, `<br>`, `<div>`, `<li>`, headings, …) become paragraph
    /// boundaries; remaining inline tags are stripped and entities decoded **per paragraph**.
    /// Empty/whitespace-only paragraphs are dropped. Returns `[]` for empty input — never
    /// indexes into a string, so it cannot crash on malformed markup.
    static func paragraphs(_ html: String) -> [String] {
        guard !html.isEmpty else { return [] }

        // 1. Replace block-tag boundaries with a newline sentinel so we can split safely.
        let sentinel = "\u{1}"  // not present in normal text
        let nsRange = NSRange(html.startIndex..., in: html)
        let broken = blockBreakRegex?.stringByReplacingMatches(
            in: html, range: nsRange, withTemplate: sentinel
        ) ?? html

        // 2. Split, then strip + decode each chunk (reuses the single-string path).
        return broken
            .components(separatedBy: sentinel)
            .map { strip($0) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Private

    private static func decodeEntities(_ input: String) -> String {
        var s = input
        for (entity, replacement) in entityMap {
            s = s.replacingOccurrences(of: entity, with: replacement)
        }

        guard let numericEntityRegex else { return s }
        
        // BUG_REPORT: Fixed crash due to invalidated String.Index during mutation.
        var result = ""
        var lastIndex = s.startIndex
        let range = NSRange(s.startIndex..., in: s)
        let matches = numericEntityRegex.matches(in: s, range: range)
        for match in matches {
            guard let entityRange = Range(match.range, in: s),
                  let codeRange  = Range(match.range(at: 1), in: s),
                  let code       = UInt32(s[codeRange]),
                  let scalar     = Unicode.Scalar(code) else { continue }
            result += s[lastIndex..<entityRange.lowerBound]
            result += String(scalar)
            lastIndex = entityRange.upperBound
        }
        result += s[lastIndex..<s.endIndex]
        return result
    }
}
