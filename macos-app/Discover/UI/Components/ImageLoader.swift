import Foundation
import ImageIO
import CoreGraphics

#if canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage
#elseif canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
#endif

/// A `Sendable` wrapper so decoded platform images can cross actor boundaries.
/// `NSImage`/`UIImage` aren't `Sendable`, but the instances produced here are created once and
/// never mutated, so sharing them is safe.
final class ImageBox: @unchecked Sendable {
    let image: PlatformImage
    init(_ image: PlatformImage) { self.image = image }
}

/// Shared, cached, **downsampling** image loader.
///
/// Why this exists: SwiftUI's `AsyncImage` does not cache decoded images, so in a scrolling
/// masonry grid every card re-downloads and re-decodes its thumbnail each time it reappears —
/// the dominant cause of scroll jank in Discover. This loader:
///   • caches decoded, downsampled images in a size-capped `NSCache`;
///   • de-duplicates concurrent requests for the same key (no thundering herd);
///   • downsamples via ImageIO so a 2000px source isn't decoded full-size into a 160pt card;
///   • keeps an on-disk `URLCache` so bytes survive relaunches.
actor ImageLoader {
    static let shared = ImageLoader()

    private let cache = NSCache<NSString, ImageBox>()
    private var inFlight: [NSString: Task<ImageBox?, Never>] = [:]
    private let session: URLSession

    private init() {
        cache.countLimit = 600
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = URLCache(memoryCapacity: 16 * 1024 * 1024,
                                   diskCapacity: 128 * 1024 * 1024)
        config.timeoutIntervalForRequest = 15
        session = URLSession(configuration: config)
    }

    /// Returns a decoded, downsampled image for `url` whose largest side is at most `maxPixel`
    /// device pixels. Cached after first load; concurrent requests for the same key share a fetch.
    func image(for url: URL, maxPixel: CGFloat) async -> ImageBox? {
        let key = "\(url.absoluteString)|\(Int(maxPixel))" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        if let existing = inFlight[key] { return await existing.value }

        let session = self.session
        let task = Task<ImageBox?, Never> {
            await Self.fetchAndDownsample(url: url, maxPixel: maxPixel, session: session)
        }
        inFlight[key] = task
        let box = await task.value
        inFlight[key] = nil
        if let box { cache.setObject(box, forKey: key) }
        return box
    }

    // `static` ⇒ runs off the actor, so network + decode never block other cache lookups.
    private static func fetchAndDownsample(url: URL, maxPixel: CGFloat, session: URLSession) async -> ImageBox? {
        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await session.data(for: request) else { return nil }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { return nil }
        guard let cg = downsample(data: data, maxPixel: maxPixel) else { return nil }
        #if canImport(AppKit)
        return ImageBox(NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height)))
        #else
        return ImageBox(UIImage(cgImage: cg))
        #endif
    }

    private static func downsample(data: Data, maxPixel: CGFloat) -> CGImage? {
        let srcOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let src = CGImageSourceCreateWithData(data as CFData, srcOptions) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, maxPixel),
        ]
        return CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary)
    }
}
