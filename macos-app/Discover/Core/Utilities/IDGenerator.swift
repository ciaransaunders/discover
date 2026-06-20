import Foundation

/// Generates stable, deduplicated article identifiers.
///
/// Algorithm: two-pass DJB2 hash — first hash `feedUrl + "::" + guid`,
/// then hash the decimal string of that result and concatenate.
/// Identical to the TypeScript implementation in `lib/fetchFeeds.ts`.
enum IDGenerator {

    // MARK: - Public API

    /// Returns a stable string identifier for an article.
    /// - Parameters:
    ///   - feedUrl: The normalised URL of the RSS feed.
    ///   - guid:    The `<guid>` / `<id>` element from the feed item.
    static func generate(feedUrl: String, guid: String) -> String {
        let input = "\(feedUrl)::\(guid)"
        let hash1 = djb2(input)
        let hash2 = djb2(String(hash1))
        return "\(hash1)\(hash2)"
    }

    // MARK: - Private

    /// DJB2 hash using wrapping (overflow) arithmetic to match JavaScript's
    /// BigInt behaviour clamped to UInt64.
    private static func djb2(_ string: String) -> UInt64 {
        var hash: UInt64 = 5381
        for scalar in string.unicodeScalars {
            hash = hash &* 33 &+ UInt64(scalar.value)
        }
        return hash
    }
}
