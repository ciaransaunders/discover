import Foundation

/// Extracts the best available thumbnail URL from a `ParsedItem`.
///
/// Priority (mirrors `extractThumbnail()` in `lib/fetchFeeds.ts`):
///   1. `media:content` with an image MIME type or image file extension
///   2. `media:thumbnail`
///   3. `enclosure` with an image MIME type or image extension
///   4. First `<img src="…">` found in the description / content body
enum ThumbnailExtractor {

    private static let imgRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"<img[^>]+src=["']([^"']+)["']"#,
        options: .caseInsensitive
    )

    private static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "webp", "gif", "avif",
    ]

    // MARK: - Public API

    /// Returns the best thumbnail URL for `item`, or `nil` if none found.
    static func extract(from item: ParsedItem) -> String? {
        // 1. media:content — the RSS media namespace explicitly denotes media attachments.
        //    Accept any URL here; skip only if the MIME type is explicitly non-image (e.g. video/).
        //    CDN URLs commonly have no file extension and no type attribute, so we cannot
        //    require either — accepting the URL is the correct default.
        if let url = item.mediaUrl, !url.isEmpty {
            let mimeOk = item.mediaType.map { $0.hasPrefix("image/") } ?? true
            if mimeOk { return url }
        }

        // 2. media:thumbnail
        if let url = item.thumbnail, !url.isEmpty { return url }

        // 3. enclosure — keep the MIME/extension check here since enclosures can be audio/video.
        if let url = item.enclosureUrl, looksLikeImage(url, mimeType: item.enclosureType) {
            return url
        }

        // 4. First <img> in body HTML (description or full content).
        let body = item.content.isEmpty ? item.description : item.content
        return firstImgSrc(in: body)
    }

    // MARK: - Private

    private static func looksLikeImage(_ url: String, mimeType: String?) -> Bool {
        if let mime = mimeType { return mime.hasPrefix("image/") }
        let ext = URL(string: url)?.pathExtension.lowercased() ?? ""
        return imageExtensions.contains(ext)
    }

    private static func firstImgSrc(in html: String) -> String? {
        guard !html.isEmpty else { return nil }
        guard let imgRegex else { return nil }
        let range = NSRange(html.startIndex..., in: html)
        guard let match = imgRegex.firstMatch(in: html, range: range),
              let srcRange = Range(match.range(at: 1), in: html) else { return nil }
        let src = String(html[srcRange])
        // Skip data URIs and 1-pixel trackers.
        guard !src.hasPrefix("data:"),
              !src.contains("pixel"),
              !src.contains("track"),
              src.contains(".") else { return nil }
        return src
    }
}
