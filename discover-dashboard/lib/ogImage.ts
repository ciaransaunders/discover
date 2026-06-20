/**
 * OG Image Scraper
 *
 * Fetches the Open Graph image from an article's HTML page.
 * Used as a fallback when RSS feeds provide low-resolution thumbnails
 * (e.g. BBC, Sky News).
 */

const OG_SCRAPE_TIMEOUT_MS = 5000;

/**
 * Scrape the og:image meta tag from an article URL.
 * Returns the image URL or null if not found / on error.
 */
export async function scrapeOgImage(
    articleUrl: string
): Promise<string | null> {
    try {
        const controller = new AbortController();
        const timeout = setTimeout(
            () => controller.abort(),
            OG_SCRAPE_TIMEOUT_MS
        );

        const response = await fetch(articleUrl, {
            signal: controller.signal,
            headers: {
                "User-Agent":
                    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Discover-Dashboard/1.0",
                Accept: "text/html",
            },
            redirect: "follow",
        });

        clearTimeout(timeout);

        if (!response.ok) return null;

        // Only read the first ~50KB to find the <head> — no need to download the full page
        const reader = response.body?.getReader();
        if (!reader) return null;

        let html = "";
        const decoder = new TextDecoder();
        const MAX_BYTES = 50 * 1024;

        while (html.length < MAX_BYTES) {
            const { done, value } = await reader.read();
            if (done) break;
            html += decoder.decode(value, { stream: true });

            // Early exit once we've passed </head>
            if (html.includes("</head>")) break;
        }

        // Cancel the rest of the download
        reader.cancel().catch(() => { });

        // Match <meta property="og:image" content="...">
        // Handle both single and double quotes, and varying attribute order
        const ogMatch = html.match(
            /<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']/i
        );
        if (ogMatch) return ogMatch[1];

        // Also check reverse attribute order: content before property
        const reverseMatch = html.match(
            /<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:image["']/i
        );
        if (reverseMatch) return reverseMatch[1];

        return null;
    } catch (error) {
        // Silently fail — the RSS image (or null) will be used instead
        return null;
    }
}

/**
 * Resolve the best image for an article.
 *
 * - If `useOgImage` is true: scrape the OG image, fall back to RSS image.
 * - If `useOgImage` is false: use the RSS image as-is (existing behaviour).
 */
export async function resolveImage(
    rssImage: string | null,
    articleUrl: string,
    useOgImage: boolean
): Promise<string | null> {
    if (!useOgImage) return rssImage;

    const ogImage = await scrapeOgImage(articleUrl);
    return ogImage || rssImage;
}
