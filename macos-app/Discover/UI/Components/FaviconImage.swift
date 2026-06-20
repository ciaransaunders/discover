import SwiftUI

/// Loads and displays the favicon for a given URL's domain via Google's
/// public favicon service. Falls back to a generic globe icon on failure.
struct FaviconImage: View {
    let urlString: String
    var size: CGFloat = 16

    private var faviconURL: URL? {
        guard let host = URLComponents(string: urlString)?.host else { return nil }
        let bare = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        return URL(string: "https://www.google.com/s2/favicons?domain=\(bare)&sz=64")
    }

    var body: some View {
        if let url = faviconURL {
            // Cached + downsampled so favicons aren't re-fetched from Google on every scroll.
            CachedAsyncImage(url: url, maxPixel: 128, contentMode: .fit) {
                fallbackIcon
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        } else {
            fallbackIcon
        }
    }

    private var fallbackIcon: some View {
        Image(systemName: "globe")
            .font(.system(size: size * 0.75))
            .foregroundStyle(.secondary)
            .frame(width: size, height: size)
    }
}
