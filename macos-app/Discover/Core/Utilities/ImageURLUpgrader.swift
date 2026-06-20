import Foundation

/// Best-effort rewriting of common low-resolution image-CDN URLs to higher-resolution variants.
///
/// RSS feeds frequently ship small thumbnails; where the CDN encodes the rendition size in the URL
/// path we can request a larger one for free — no extra network round-trip (unlike `og:image`
/// scraping). This is deliberately **conservative**: it only rewrites well-known, signature-free
/// patterns and otherwise returns the input unchanged, so it can never break a working URL.
///
/// Notably it does NOT touch query-signed CDNs (e.g. Guardian `i.guim.co.uk` URLs carry an `s=`
/// HMAC that changing `width=` would invalidate).
enum ImageURLUpgrader {

    static func upgrade(_ urlString: String) -> String {
        guard !urlString.isEmpty else { return urlString }
        var s = urlString

        // BBC iChef: bump the width path segment to a high-res rendition the CDN serves.
        // e.g. https://ichef.bbci.co.uk/news/240/cpsprodpb/...  ->  /news/976/...
        s = replace(
            s,
            pattern: #"(ichef\.bbci?\.co\.uk/(?:news/ws|ace/standard|ace/ws|news|sport|food|standard)/)\d{2,4}/"#,
            template: "$1976/")

        // WordPress-style resize suffix: foo-150x150.jpg -> foo.jpg (the original full-size asset).
        s = replace(
            s,
            pattern: #"-\d{2,4}x\d{2,4}(\.(?:jpe?g|png|webp|avif|gif))"#,
            template: "$1")

        return s
    }

    private static func replace(_ input: String, pattern: String, template: String) -> String {
        guard let re = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return input
        }
        let range = NSRange(input.startIndex..., in: input)
        return re.stringByReplacingMatches(in: input, range: range, withTemplate: template)
    }
}
