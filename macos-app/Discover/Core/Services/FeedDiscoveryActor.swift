import Foundation
import OSLog

// MARK: - Discovery result (Sendable value type)

/// Result of resolving a user-entered URL to a concrete RSS/Atom feed.
struct FeedDiscoveryResult: Sendable {
    /// The resolved feed URL (may differ from the input if autodiscovery followed a `<link>`).
    let feedUrl: String
    /// The feed's `<title>`, if present — used to infer a display name.
    let feedTitle: String?
    /// Items prefetched during discovery; the caller can upsert them immediately.
    let items: [ParsedItem]
}

/// Errors surfaced to the add-by-URL UI.
enum FeedDiscoveryError: LocalizedError, Sendable {
    case invalidURL
    case noFeedFound
    case network(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:        return "That doesn't look like a valid URL."
        case .noFeedFound:       return "No RSS or Atom feed could be found at that address."
        case .network(let msg):  return msg
        }
    }
}

// MARK: - Feed discovery actor

/// Resolves a user-entered URL to a concrete RSS/Atom feed.
///
/// Design contract (Swift 6), mirroring `RSSFetcherActor` / `OGImageActor`:
/// - This actor owns **only** network/parse work — no SwiftData, no UI.
/// - Inputs/outputs are `Sendable`; callers (on `@MainActor`) handle persistence.
///
/// Strategy:
///   1. Normalise the input URL and try fetching it as a feed directly.
///   2. If that yields zero items, stream the page HTML (capped ~100 KB like `OGImageActor`),
///      scan for `<link rel="alternate" type="application/rss+xml|atom+xml" href>`, resolve
///      relative hrefs against the base URL, and retry the first candidate.
actor FeedDiscoveryActor {

    // MARK: - Singleton

    static let shared = FeedDiscoveryActor()
    private init() {}

    // MARK: - Configuration

    private let byteLimit = 100 * 1024  // 100 KB cap for HTML autodiscovery
    private let timeout: TimeInterval = 12

    // MARK: - Public API

    /// Resolves `rawURL` to a feed, prefetching its items.
    func discover(from rawURL: String) async throws -> FeedDiscoveryResult {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw FeedDiscoveryError.invalidURL }

        let normalised = Self.normaliseInput(trimmed)
        guard let baseURL = URL(string: normalised), baseURL.scheme != nil else {
            throw FeedDiscoveryError.invalidURL
        }

        // 1. Try the URL directly as a feed.
        if let direct = try await fetchAsFeed(urlString: normalised), !direct.items.isEmpty {
            return direct
        }

        // 2. Treat the URL as a web page; scan for <link rel="alternate"> feed references.
        guard let html = await fetchHTML(from: baseURL) else {
            throw FeedDiscoveryError.noFeedFound
        }
        let candidates = Self.extractFeedLinks(fromHTML: html, baseURL: baseURL)
        guard !candidates.isEmpty else { throw FeedDiscoveryError.noFeedFound }

        for candidate in candidates {
            if let result = try await fetchAsFeed(urlString: candidate), !result.items.isEmpty {
                return result
            }
        }

        throw FeedDiscoveryError.noFeedFound
    }

    // MARK: - Pure helpers (tested directly)

    /// Adds an `https://` scheme if the user omitted one. Pure; safe to test.
    static func normaliseInput(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
            return trimmed
        }
        // Some users paste the `feed:` scheme from a browser.
        if trimmed.lowercased().hasPrefix("feed://") {
            return "https://" + trimmed.dropFirst("feed://".count)
        }
        return "https://" + trimmed
    }

    /// Extracts feed URLs from an HTML document's `<link rel="alternate" type="…rss|atom…">` tags.
    ///
    /// Pure (no I/O) so it can be unit-tested against fixtures. Relative `href`s are resolved
    /// against `baseURL`. Returns candidates in document order; RSS/Atom only.
    static func extractFeedLinks(fromHTML html: String, baseURL: URL) -> [String] {
        var results: [String] = []
        var seen = Set<String>()
        let range = NSRange(html.startIndex..., in: html)

        for regex in linkPatterns {
            regex.enumerateMatches(in: html, range: range) { match, _, _ in
                guard let match, match.numberOfRanges >= 2,
                      let hrefRange = Range(match.range(at: 1), in: html) else { return }
                let href = String(html[hrefRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !href.isEmpty else { return }
                guard let resolved = resolve(href, relativeTo: baseURL) else { return }
                if seen.insert(resolved).inserted { results.append(resolved) }
            }
        }
        return results
    }

    // MARK: - Private: network

    /// Fetches `urlString` and attempts to parse it as a feed. Returns `nil` on network failure
    /// or when the document isn't parseable as a feed.
    private func fetchAsFeed(urlString: String) async throws -> FeedDiscoveryResult? {
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return nil }
            guard (200..<300).contains(http.statusCode) else { return nil }

            let diagnostics = RSSParser.parseWithDiagnostics(
                data: data,
                feedUrl: urlString,
                feedName: "",
                category: ""
            )
            if diagnostics.items.isEmpty { return nil }
            return FeedDiscoveryResult(
                feedUrl: urlString,
                feedTitle: diagnostics.feedTitle,
                items: diagnostics.items
            )
        } catch let error as URLError {
            // Propagate genuine connectivity failures so the UI can show "Offline" etc.
            if error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
                throw FeedDiscoveryError.network("You appear to be offline.")
            }
            return nil
        } catch {
            return nil
        }
    }

    /// Streams the first ~100 KB of an HTML page (OGImageActor-style) for autodiscovery.
    private func fetchHTML(from url: URL) async -> String? {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")

        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }

            var buffer = Data()
            for try await byte in bytes {
                buffer.append(byte)
                if buffer.count >= byteLimit { break }
            }
            return String(decoding: buffer, as: UTF8.self)
        } catch {
            return nil
        }
    }

    // MARK: - Private: static config / parsing

    private static let userAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36"

    /// Matches `<link …>` tags whose `type` is an RSS/Atom mime type, in either attribute order
    /// (href before type, or type before href).
    private static let linkPatterns: [NSRegularExpression] = [
        // type before href
        #"<link\b[^>]*type=["']application/(?:rss|atom)\+xml["'][^>]*href=["']([^"']+)["']"#,
        // href before type
        #"<link\b[^>]*href=["']([^"']+)["'][^>]*type=["']application/(?:rss|atom)\+xml["']"#,
    ].compactMap { try? NSRegularExpression(pattern: $0, options: .caseInsensitive) }

    /// Resolves a possibly-relative href against the page's base URL.
    private static func resolve(_ href: String, relativeTo base: URL) -> String? {
        if href.lowercased().hasPrefix("http://") || href.lowercased().hasPrefix("https://") {
            return href
        }
        if href.hasPrefix("//") {
            let scheme = base.scheme ?? "https"
            return "\(scheme):\(href)"
        }
        return URL(string: href, relativeTo: base)?.absoluteString
    }
}
