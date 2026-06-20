import SwiftUI

/// A drop-in replacement for `AsyncImage` that loads through `ImageLoader`, so decoded+downsampled
/// images are cached across scrolls instead of being re-fetched every time a card reappears.
///
/// `maxPixel` is the largest side, in **device pixels**, the source should be downsampled to.
struct CachedAsyncImage<Placeholder: View>: View {
    private let url: URL?
    private let maxPixel: CGFloat
    private let contentMode: ContentMode
    @ViewBuilder private let placeholder: () -> Placeholder

    @State private var image: PlatformImage?

    init(
        url: URL?,
        maxPixel: CGFloat = 1000,
        contentMode: ContentMode = .fill,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.maxPixel = maxPixel
        self.contentMode = contentMode
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image {
                #if canImport(AppKit)
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: contentMode)
                #else
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: contentMode)
                #endif
            } else {
                placeholder()
            }
        }
        // Re-runs when the URL changes (essential for LazyVGrid cell reuse).
        .task(id: url) {
            guard let url else {
                image = nil
                return
            }
            let box = await ImageLoader.shared.image(for: url, maxPixel: maxPixel)
            if !Task.isCancelled {
                image = box?.image
            }
        }
    }
}
