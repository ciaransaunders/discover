import Foundation

/// Utility that strips tracking parameters, normalises hosts, and produces
/// human-readable source names — a direct port of the TypeScript helpers
/// in `lib/fetchFeeds.ts`.
enum URLNormaliser {

    private static let blockedParams: Set<String> = [
        "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",
        "utm_id", "utm_source_platform", "utm_creative_format", "utm_marketing_tactic",
        "fbclid", "gclid", "msclkid", "mc_cid", "mc_eid", "_ga", "ref",
    ]

    // MARK: - Public API

    /// Strips UTM / tracking query params, removes `www.` prefix, and trims
    /// the trailing slash. Returns the original string on parse failure.
    static func normalise(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed) else { return raw }

        // Remove blocked query params.
        if let items = components.queryItems {
            let filtered = items.filter { !blockedParams.contains($0.name) }
            components.queryItems = filtered.isEmpty ? nil : filtered
        }

        // Strip leading www.
        if let host = components.host, host.hasPrefix("www.") {
            components.host = String(host.dropFirst(4))
        }

        // Remove trailing slash (but leave bare roots alone).
        var path = components.path
        if path.hasSuffix("/"), path.count > 1 {
            path = String(path.dropLast())
            components.path = path
        }

        return components.url?.absoluteString ?? raw
    }

    /// Returns a short human-readable source label derived from the URL host.
    /// E.g. `"https://www.theverge.com/ai"` → `"theverge"`.
    static func sourceName(from urlString: String) -> String {
        guard let host = URLComponents(string: urlString)?.host else { return urlString }
        let stripped = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        return stripped.split(separator: ".").first.map(String.init) ?? stripped
    }
}
