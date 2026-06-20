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
