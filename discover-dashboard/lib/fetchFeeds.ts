import Parser from "rss-parser";
import { Article, FeedConfig } from "./types";
import { feeds } from "./feeds";
import { readCache, writeCache, CacheData } from "./cache";
import { resolveImage } from "./ogImage";

/**
 * Cache configuration. 
 * Default is 15 minutes. This is a stale-while-revalidate threshold.
 */
const CACHE_MAX_AGE_MINUTES = 15;
const CACHE_MAX_AGE_MS = CACHE_MAX_AGE_MINUTES * 60 * 1000;

const parser = new Parser({
  timeout: 10000,
  headers: {
    "User-Agent":
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Discover-Dashboard/1.0",
    Accept: "application/rss+xml, application/xml, text/xml, */*",
  },
  customFields: {
    item: [
      ["media:content", "mediaContent", { keepArray: false }],
      ["media:thumbnail", "mediaThumbnail", { keepArray: false }],
      ["enclosure", "enclosure", { keepArray: false }],
    ],
  },
});

function stripHtml(html: string): string {
  if (!html) return "";
  return html
    // Remove script and style tags and their contents
    .replace(/<(script|style)[^>]*>[\s\S]*?<\/\1>/gi, "")
    // Remove all other HTML tags
    .replace(/<[^>]*>/g, "")
    // Decode common entities
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    // Collapse whitespace
    .replace(/\s+/g, " ")
    .trim();
}

/** Truncate snippet at a sentence boundary, max `maxLen` chars */
function truncateSnippet(text: string, maxLen: number = 200): string {
  const clean = stripHtml(text);
  if (clean.length <= maxLen) return clean;
  // Find the last sentence-ending punctuation before maxLen
  const truncated = clean.slice(0, maxLen);
  const lastSentence = truncated.search(/[.!?][^.!?]*$/);
  if (lastSentence > maxLen * 0.4) {
    return truncated.slice(0, lastSentence + 1);
  }
  // Fall back to word boundary
  const lastSpace = truncated.lastIndexOf(" ");
  return (lastSpace > 0 ? truncated.slice(0, lastSpace) : truncated) + "…";
}

/** Normalise a URL for deduplication: strip tracking params, trailing slash, www */
function normaliseUrl(url: string): string {
  try {
    const u = new URL(url);
    // Remove common tracking parameters
    const trackingParams = [
      "utm_source", "utm_medium", "utm_campaign", "utm_content", "utm_term",
      "ref", "source", "fbclid", "gclid", "mc_cid", "mc_eid",
    ];
    trackingParams.forEach((p) => u.searchParams.delete(p));
    // Remove www prefix
    u.hostname = u.hostname.replace(/^www\./, "");
    // Remove trailing slash
    u.pathname = u.pathname.replace(/\/+$/, "") || "/";
    return u.toString();
  } catch {
    return url;
  }
}

function extractThumbnail(item: Record<string, unknown>): string | null {
  // Try media:content
  const mediaContent = item.mediaContent as
    | Record<string, unknown>
    | undefined;
  if (mediaContent) {
    const attrs = (mediaContent.$ as Record<string, string>) || mediaContent;
    if (attrs.url) return attrs.url as string;
  }

  // Try media:thumbnail
  const mediaThumbnail = item.mediaThumbnail as
    | Record<string, unknown>
    | undefined;
  if (mediaThumbnail) {
    const attrs = (mediaThumbnail.$ as Record<string, string>) || mediaThumbnail;
    if (attrs.url) return attrs.url as string;
  }

  // Try enclosure
  const enclosure = item.enclosure as Record<string, unknown> | undefined;
  if (enclosure) {
    const url = (enclosure.url as string) || ((enclosure.$ as Record<string, string>)?.url);
    const type = (enclosure.type as string) || ((enclosure.$ as Record<string, string>)?.type) || "";
    if (url && type.startsWith("image")) return url;
  }

  // Try to find image in content
  const content =
    (item["content:encoded"] as string) ||
    (item.content as string) ||
    "";
  const imgMatch = content.match(/<img[^>]+src=["']([^"']+)["']/);
  if (imgMatch) return imgMatch[1];

  return null;
}

function generateId(item: Record<string, unknown>, feedUrl: string): string {
  const guid = (item.guid as string) || (item.id as string) || (item.link as string) || "";
  // Combine feed URL + article GUID for uniqueness across feeds
  const seed = feedUrl + "::" + guid;
  // Two-pass djb2 hash for wider distribution
  let h1 = 5381;
  let h2 = 52711;
  for (let i = 0; i < seed.length; i++) {
    const char = seed.charCodeAt(i);
    h1 = ((h1 << 5) + h1 + char) | 0;
    h2 = ((h2 << 5) + h2 + char) | 0;
  }
  return Math.abs(h1).toString(36) + Math.abs(h2).toString(36);
}

async function fetchSingleFeed(feedConfig: FeedConfig): Promise<Article[]> {
  try {
    const feed = await parser.parseURL(feedConfig.url);
    const maxItems = feedConfig.maxItems || 15;
    const items = (feed.items || []).slice(0, maxItems);

    const articles: Article[] = items.map((item) => {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const raw = item as any;
      const rawSnippet =
        item.contentSnippet ||
        item.summary ||
        raw["content:encodedSnippet"] ||
        item.content ||
        "";
      const snippet = truncateSnippet(rawSnippet);

      return {
        id: generateId(raw, feedConfig.url),
        title: item.title || "Untitled",
        snippet,
        link: item.link || "#",
        source: feedConfig.name,
        category: feedConfig.category,
        thumbnail: extractThumbnail(raw),
        publishedAt: item.pubDate || item.isoDate || new Date().toISOString(),
        feedUrl: feedConfig.url,
      };
    });

    // For feeds flagged with useOgImage, resolve higher-quality images
    if (feedConfig.useOgImage) {
      const imageResults = await Promise.allSettled(
        articles.map((article) =>
          resolveImage(article.thumbnail, article.link, true)
        )
      );
      imageResults.forEach((result, i) => {
        if (result.status === "fulfilled" && result.value) {
          articles[i].thumbnail = result.value;
        }
      });
    }

    return articles;
  } catch (error) {
    console.error(`Failed to fetch feed: ${feedConfig.name} (${feedConfig.url})`, error);
    return [];
  }
}

function deduplicateAndSort(articles: Article[]): Article[] {
  // Sort by date, newest first
  articles.sort(
    (a, b) =>
      new Date(b.publishedAt).getTime() - new Date(a.publishedAt).getTime()
  );

  // Deduplicate by normalised link
  const seen = new Set<string>();
  return articles.filter((article) => {
    const normLink = normaliseUrl(article.link);
    if (seen.has(normLink)) return false;
    seen.add(normLink);
    return true;
  });
}

async function fetchFresh(feedList: FeedConfig[] = feeds): Promise<Article[]> {
  const results = await Promise.allSettled(feedList.map(fetchSingleFeed));

  const articles: Article[] = [];
  for (const result of results) {
    if (result.status === "fulfilled") {
      articles.push(...result.value);
    }
  }

  return deduplicateAndSort(articles);
}

export interface FetchResult {
  articles: Article[];
  lastUpdated: number;
  fromCache: boolean;
}

/**
 * Fetch all feeds with stale-while-revalidate pattern.
 * - If cache exists and is fresh (<15 min), return cached.
 * - If cache is stale, return cached immediately, queue background refresh.
 * - If no cache, fetch fresh.
 */
export async function fetchAllFeeds(): Promise<FetchResult> {
  const cached = await readCache();

  if (cached && (Date.now() - cached.lastUpdated) < CACHE_MAX_AGE_MS) {
    // Fresh cache — return immediately
    return { articles: cached.articles, lastUpdated: cached.lastUpdated, fromCache: true };
  }

  if (cached) {
    // Stale cache — return stale data, trigger background refresh
    // (The background refresh writes to cache for next load)
    fetchFresh().then((freshArticles) => {
      writeCache(freshArticles);
    }).catch((err) => {
      console.error("Background refresh failed:", err);
    });
    return { articles: cached.articles, lastUpdated: cached.lastUpdated, fromCache: true };
  }

  // No cache — fetch fresh (first run)
  const articles = await fetchFresh();
  await writeCache(articles);
  return { articles, lastUpdated: Date.now(), fromCache: false };
}

/** Fetch specific feeds (used by the API route for dynamic refetch) */
export async function fetchSpecificFeeds(feedList: FeedConfig[]): Promise<Article[]> {
  const freshArticles = await fetchFresh(feedList);

  // Merge into existing cache instead of overwriting
  const cached = await readCache();
  if (cached) {
    // Remove old articles whose feedUrl matches one of the refreshed feeds
    const refreshedUrls = new Set(feedList.map((f) => f.url));
    const kept = cached.articles.filter(
      (a) => !a.feedUrl || !refreshedUrls.has(a.feedUrl)
    );
    const merged = deduplicateAndSort([...freshArticles, ...kept]);
    await writeCache(merged);
    return merged;
  }

  await writeCache(freshArticles);
  return freshArticles;
}
