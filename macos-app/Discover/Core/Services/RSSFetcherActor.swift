import Foundation
import OSLog


// MARK: - Feed descriptor (Sendable value type for crossing actor boundaries)

/// Sendable snapshot of a `FeedModel` row; safe to pass across actor boundaries.
struct FeedDescriptor: Sendable {
    let url:        String
    let name:       String
    let category:   String
    let useOgImage: Bool
}

/// Result of a single feed fetch operation.
struct FeedFetchResult: Sendable {
    let feedUrl: String
    let items: [ParsedItem]
    let error: String?
}

// MARK: - RSS fetcher actor

/// Handles all RSS network fetching and parsing.
///
/// Design contract (Swift 6):
/// - This actor owns **only** network/parse work — no SwiftData access.
/// - Callers (on `@MainActor`) extract `FeedDescriptor` values from SwiftData,
///   pass them here, and receive back results — which are Sendable.
/// - Upsert into SwiftData happens back on `@MainActor` in the ViewModel.
actor RSSFetcherActor {

    // MARK: - Singleton

    static let shared = RSSFetcherActor()
    private init() {}

    // MARK: - Configuration

    private let fetchTimeout: TimeInterval = 15

    // MARK: - Public API

    /// Fetches all supplied feeds concurrently and returns the results.
    func fetchAll(feeds: [FeedDescriptor]) async -> [FeedFetchResult] {
        Logger.networking.info("Starting concurrent fetch of \(feeds.count) feeds")
        return await withTaskGroup(of: FeedFetchResult.self) { group in
            for feed in feeds {
                group.addTask { await self.fetchOne(feed: feed) }
            }
            var results: [FeedFetchResult] = []
            for await result in group { results.append(result) }
            return results
        }
    }

    /// Fetches a single feed by its descriptor.
    func fetchOne(feed: FeedDescriptor) async -> FeedFetchResult {
        guard let url = URL(string: feed.url) else { 
            Logger.networking.error("Invalid feed URL: \(feed.url, privacy: .public)")
            return FeedFetchResult(feedUrl: feed.url, items: [], error: "Invalid URL") 
        }

        Logger.networking.debug("Fetching feed: \(feed.name, privacy: .public) (\(feed.url, privacy: .public))")
        var request = URLRequest(url: url, timeoutInterval: fetchTimeout)
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return FeedFetchResult(feedUrl: feed.url, items: [], error: "Invalid response")
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                return FeedFetchResult(feedUrl: feed.url, items: [], error: "HTTP \(httpResponse.statusCode)") 
            }

            let parsed = RSSParser.parseWithDiagnostics(
                data:     data,
                feedUrl:  feed.url,
                feedName: feed.name,
                category: feed.category
            )
            if parsed.items.isEmpty, let err = parsed.parserError {
                return FeedFetchResult(feedUrl: feed.url, items: [], error: "Parse failed: \(err.localizedDescription)")
            }
            var items = parsed.items

            // Resolve thumbnails from RSS metadata.
            items = items.map { item in
                var copy = item
                if copy.thumbnail == nil {
                    copy.thumbnail = ThumbnailExtractor.extract(from: item)
                }
                return copy
            }

            // Optionally enrich with OG images (feed-level opt-in).
            if feed.useOgImage {
                items = await enrichWithOGImages(items)
            }

            Logger.networking.info("Successfully fetched \(items.count) items from \(feed.name, privacy: .public)")
            return FeedFetchResult(feedUrl: feed.url, items: items, error: nil)

        } catch { 
            Logger.networking.error("Failed to fetch \(feed.name, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return FeedFetchResult(feedUrl: feed.url, items: [], error: userFacingError(from: error)) 
        }
    }

    // MARK: - Private

    private func userFacingError(from error: any Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return "Offline"
            case .timedOut:
                return "Timed out"
            case .cannotFindHost, .dnsLookupFailed:
                return "DNS lookup failed"
            case .cannotConnectToHost:
                return "Can't connect to host"
            case .networkConnectionLost:
                return "Connection lost"
            case .secureConnectionFailed,
                 .serverCertificateHasBadDate,
                 .serverCertificateUntrusted,
                 .serverCertificateHasUnknownRoot,
                 .serverCertificateNotYetValid:
                return "Secure connection failed"
            case .badURL:
                return "Invalid URL"
            default:
                break
            }
        }
        return error.localizedDescription
    }

    private func enrichWithOGImages(_ items: [ParsedItem]) async -> [ParsedItem] {
        await withTaskGroup(of: ParsedItem.self) { group in
            for item in items {
                group.addTask {
                    var copy = item
                    if copy.thumbnail == nil || copy.thumbnail?.isEmpty == true {
                        copy.thumbnail = await OGImageActor.shared.ogImage(for: item.link)
                    }
                    return copy
                }
            }
            var result: [ParsedItem] = []
            for await item in group { result.append(item) }
            return result
        }
    }
}
