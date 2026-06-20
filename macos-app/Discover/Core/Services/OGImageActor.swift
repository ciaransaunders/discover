import Foundation

/// An actor that fetches the `og:image` meta tag from article pages.
///
/// - Reads only the first 50 KB of each page (streaming) to keep it fast.
/// - Caches results in-memory for the duration of the app session.
/// - One shared singleton (`OGImageActor.shared`).
actor OGImageActor {

  // MARK: - Singleton

  static let shared = OGImageActor()
  private init() {}

  // MARK: - State

  private var cache: [String: String?] = [:]  // nil = "already tried, no image"

  private let byteLimit = 50 * 1024  // 50 KB
  private let timeout: TimeInterval = 8

  // MARK: - Public API

  /// Returns the og:image URL for `articleURL`, or `nil` if unavailable.
  func ogImage(for articleURL: String) async -> String? {
    if let cached = cache[articleURL] { return cached }
    let result = await fetch(articleURL)

    // BUG_REPORT: Fixed unbounded memory leak in OGImage cache
    if cache.count > 500 {
      cache.removeAll(keepingCapacity: true)
    }

    cache[articleURL] = result
    return result
  }

  // MARK: - Private

  private func fetch(_ urlString: String) async -> String? {
    guard let url = URL(string: urlString) else { return nil }

    var request = URLRequest(url: url, timeoutInterval: timeout)
    request.setValue(
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36",
      forHTTPHeaderField: "User-Agent"
    )
    request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")

    do {
      let (bytes, response) = try await URLSession.shared.bytes(for: request)
      guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }

      var buffer = Data()
      for try await byte in bytes {
        buffer.append(byte)
        if buffer.count >= byteLimit { break }
      }

      // BUG_REPORT: Fixed fragile string instantiation when scraping HTML chunks
      let html = String(decoding: buffer, as: UTF8.self)

      guard let rawURL = extractOGImage(from: html) else { return nil }
      return resolve(rawURL, relativeTo: url)

    } catch { return nil }
  }

  // MARK: - Extraction

  private static let metaPatterns: [NSRegularExpression] = [
    // property before content
    #"<meta\s+[^>]*property=["']og:image["'][^>]*content=["']([^"']+)["']"#,
    // content before property
    #"<meta\s+[^>]*content=["']([^"']+)["'][^>]*property=["']og:image["']"#,
  ].compactMap { try? NSRegularExpression(pattern: $0, options: .caseInsensitive) }

  private func extractOGImage(from html: String) -> String? {
    let range = NSRange(html.startIndex..., in: html)
    for regex in OGImageActor.metaPatterns {
      if let match = regex.firstMatch(in: html, range: range),
        let urlRange = Range(match.range(at: 1), in: html)
      {
        let candidate = String(html[urlRange])
        if !candidate.hasPrefix("data:") { return candidate }
      }
    }
    return nil
  }

  private func resolve(_ path: String, relativeTo base: URL) -> String? {
    if path.hasPrefix("http") { return path }
    return URL(string: path, relativeTo: base)?.absoluteString
  }
}
