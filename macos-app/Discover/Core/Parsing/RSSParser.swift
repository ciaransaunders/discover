import Foundation
import OSLog


// MARK: - Intermediate model (pre-SwiftData, fully Sendable)

struct ParsedItem: Sendable {
    var guid:          String = ""
    var title:         String = ""
    var link:          String = ""
    var description:   String = ""
    var content:       String = ""   // content:encoded or atom:content
    var pubDate:       Date?
    var thumbnail:     String?       // resolved by ThumbnailExtractor
    // media: namespace
    var mediaUrl:      String?
    var mediaType:     String?
    // enclosure
    var enclosureUrl:  String?
    var enclosureType: String?
    // Feed-level metadata stamped by the caller
    var feedUrl:       String = ""
    var category:      String = ""
    var feedName:      String = ""
}

// MARK: - RSS / Atom parser (native XMLParser, zero dependencies)

/// Parses RSS 2.0 and Atom 1.0 feeds using `Foundation.XMLParser`.
/// Thread-safe: create a new instance per parse call via `RSSParser.parse(data:feedUrl:)`.
final class RSSParser: NSObject, XMLParserDelegate, @unchecked Sendable {

    // MARK: - State

    private var items:         [ParsedItem] = []
    private var feedTitle:     String       = ""
    private var currentItem:   ParsedItem?
    private var currentText:   String       = ""
    private var currentLocal:  String       = ""
    private var isInItem:      Bool         = false
    private var isAtom:        Bool         = false
    private var parseError:    (any Error)?

    // Date formatters (allocated once per instance).
    private let rfc822Formatters: [DateFormatter] = {
        let locale = Locale(identifier: "en_US_POSIX")
        return [
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "EEE, dd MMM yyyy HH:mm:ss zzz",
            "dd MMM yyyy HH:mm:ss Z",
            "dd MMM yyyy HH:mm:ss zzz",
        ].map {
            let f = DateFormatter()
            f.locale = locale
            f.dateFormat = $0
            return f
        }
    }()

    private let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private let iso8601Fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // MARK: - Entry point

    /// Parse `data` and return an array of `ParsedItem`s.
    static func parse(data: Data, feedUrl: String, feedName: String = "", category: String = "") -> [ParsedItem] {
        parseWithDiagnostics(data: data, feedUrl: feedUrl, feedName: feedName, category: category).items
    }

    /// Parse `data` and return only the feed's `<title>` (channel/feed level).
    ///
    /// Used by add-by-URL autodiscovery to infer a display name. Returns `nil` when the feed
    /// has no title element.
    static func feedTitle(data: Data) -> String? {
        let parser = RSSParser()
        let xml = XMLParser(data: data)
        xml.delegate = parser
        xml.shouldProcessNamespaces       = true
        xml.shouldReportNamespacePrefixes = true
        _ = xml.parse()
        let trimmed = parser.feedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Parse `data` and return items along with any parser error.
    ///
    /// Use this when you want to distinguish "empty feed" from "parse failed".
    static func parseWithDiagnostics(
        data: Data,
        feedUrl: String,
        feedName: String = "",
        category: String = ""
    ) -> (items: [ParsedItem], parserError: (any Error)?, feedTitle: String?) {
        let parser = RSSParser()
        let xml = XMLParser(data: data)
        xml.delegate = parser
        xml.shouldProcessNamespaces       = true
        xml.shouldReportNamespacePrefixes = true
        let ok = xml.parse()

        // Stamp feed metadata onto each item.
        let items = parser.items.map { item in
            var copy      = item
            copy.feedUrl  = feedUrl
            copy.category = category
            copy.feedName = feedName.isEmpty ? URLNormaliser.sourceName(from: feedUrl) : feedName
            return copy
        }

        let err = parser.parseError ?? xml.parserError
        if let err {
            Logger.parsing.error("Parse failed for \(feedUrl, privacy: .public): \(err.localizedDescription, privacy: .public)")
        } else {
            Logger.parsing.info("Parsed \(items.count) items from \(feedUrl, privacy: .public)")
        }
        let title = parser.feedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return (items: items, parserError: ok ? nil : err, feedTitle: title.isEmpty ? nil : title)
    }

    // MARK: - XMLParserDelegate: element start

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attrs: [String: String] = [:]
    ) {
        let local = localPart(qName ?? elementName)
        currentLocal = local
        currentText  = ""

        // Detect Atom.
        if local == "feed", namespaceURI?.contains("Atom") == true { isAtom = true }

        switch local {
        case "item", "entry":
            isInItem    = true
            currentItem = ParsedItem()

        case "enclosure":
            currentItem?.enclosureUrl  = attrs["url"]
            currentItem?.enclosureType = attrs["type"]

        case "content" where isMediaNamespace(namespaceURI, qName):
            // media:content — only keep the first / a still image, ignore later ones.
            if currentItem?.mediaUrl == nil {
                currentItem?.mediaUrl  = attrs["url"]
                currentItem?.mediaType = attrs["type"]
            }

        case "thumbnail" where isMediaNamespace(namespaceURI, qName):
            if currentItem?.thumbnail == nil, let u = attrs["url"] { currentItem?.thumbnail = u }

        case "link" where isAtom:
            // <link href="…" rel="alternate"/>
            let rel = attrs["rel"] ?? "alternate"
            if (rel == "alternate" || rel.isEmpty), let href = attrs["href"] {
                currentItem?.link = href
            }

        default: break
        }
    }

    // MARK: - XMLParserDelegate: characters

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, foundCDATA data: Data) {
        currentText += String(data: data, encoding: .utf8) ?? ""
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: any Error) {
        self.parseError = parseError
    }

    func parser(_ parser: XMLParser, validationErrorOccurred validationError: any Error) {
        self.parseError = validationError
    }

    // MARK: - XMLParserDelegate: element end

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let local = localPart(qName ?? elementName)
        let text  = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        defer { currentLocal = ""; currentText = "" }

        if isInItem {
            applyToItem(local: local, namespaceURI: namespaceURI, qName: qName, text: text)
        } else if (local == "title") && feedTitle.isEmpty {
            feedTitle = text
        }
    }

    // MARK: - Apply parsed value to currentItem

    private func applyToItem(local: String, namespaceURI: String?, qName: String?, text: String) {
        let isMedia = isMediaNamespace(namespaceURI, qName)
        switch local {

        case "item", "entry":
            guard var item = currentItem else { return }
            if item.guid.isEmpty { item.guid = item.link }
            if item.description.isEmpty, !item.content.isEmpty { item.description = item.content }
            if !item.link.isEmpty { items.append(item) }
            currentItem = nil
            isInItem    = false

        case "title":
            currentItem?.title = HTMLStripper.strip(text)

        case "link" where !isAtom:
            if !text.isEmpty { currentItem?.link = text }

        case "guid", "id":
            currentItem?.guid = text

        case "description", "summary":
            // Don't overwrite a richer value already stored.
            if currentItem?.description.isEmpty == true { currentItem?.description = text }

        case "encoded" where namespaceURI?.contains("content") == true:
            currentItem?.content = text

        case "content" where !isMedia:
            // atom:content
            currentItem?.content = text

        case "pubDate", "published", "updated", "date":
            currentItem?.pubDate = parseDate(text)

        default: break
        }
    }

    // MARK: - Helpers

    private func localPart(_ name: String) -> String {
        name.split(separator: ":").last.map(String.init) ?? name
    }

    /// Detects the Media RSS (`media:`) namespace.
    ///
    /// The standard Media RSS namespace URI is `http://search.yahoo.com/mrss/`, which does
    /// **not** contain the substring "media" — so we match on the real URI (and fall back to
    /// the `media:` qualified-name prefix) rather than a naïve substring check.
    private func isMediaNamespace(_ uri: String?, _ qName: String?) -> Bool {
        if let uri {
            let lowered = uri.lowercased()
            if lowered.contains("mrss") || lowered.contains("media") { return true }
        }
        if let qName, qName.hasPrefix("media:") { return true }
        return false
    }

    private func parseDate(_ s: String) -> Date? {
        for fmt in rfc822Formatters { if let d = fmt.date(from: s) { return d } }
        if let d = iso8601.date(from: s)          { return d }
        if let d = iso8601Fractional.date(from: s) { return d }
        return nil
    }
}
