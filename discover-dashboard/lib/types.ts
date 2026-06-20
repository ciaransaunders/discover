export interface Article {
  id: string;
  title: string;
  snippet: string;
  link: string;
  source: string;
  category: string;
  thumbnail: string | null;
  publishedAt: string; // ISO string for serialization
  aiSummary?: string;
  bookmarked?: boolean;
  feedUrl?: string;
}

export interface FeedConfig {
  name: string;
  url: string;
  category: string;
  useOgImage?: boolean;  // Force OG image scraping for feeds with low-res images
  refreshInterval?: number;
  maxItems?: number;
  enabled?: boolean;
  lastFetchedAt?: number;
  lastError?: string;
  itemCount?: number;
}

export interface CategoryConfig {
  slug: string;
  label: string;
  color: string;
  icon?: string;
  priority?: number;
}
