import { NextRequest, NextResponse } from "next/server";
import { FeedConfig } from "@/lib/types";
import { fetchSpecificFeeds } from "@/lib/fetchFeeds";

const MAX_FEEDS = 100;

function isValidFeed(feed: unknown): feed is FeedConfig {
  if (typeof feed !== "object" || feed === null) return false;
  const f = feed as Record<string, unknown>;
  if (typeof f.name !== "string" || !f.name.trim()) return false;
  if (typeof f.url !== "string") return false;
  if (typeof f.category !== "string" || !f.category.trim()) return false;

  // Only allow http/https URLs to prevent SSRF
  try {
    const parsed = new URL(f.url);
    if (parsed.protocol !== "http:" && parsed.protocol !== "https:") return false;
  } catch {
    return false;
  }

  return true;
}

export async function POST(request: NextRequest) {
  try {
    let body: unknown;
    try {
      body = await request.json();
    } catch {
      return NextResponse.json(
        { error: "Invalid JSON body" },
        { status: 400 }
      );
    }

    const { feeds } = body as { feeds: unknown };

    if (!Array.isArray(feeds)) {
      return NextResponse.json(
        { error: "feeds must be an array" },
        { status: 400 }
      );
    }

    if (feeds.length > MAX_FEEDS) {
      return NextResponse.json(
        { error: `Too many feeds (max ${MAX_FEEDS})` },
        { status: 400 }
      );
    }

    const validFeeds = feeds.filter(isValidFeed);
    if (validFeeds.length === 0) {
      return NextResponse.json(
        { error: "No valid feeds provided" },
        { status: 400 }
      );
    }

    const articles = await fetchSpecificFeeds(validFeeds);

    return NextResponse.json({ articles });
  } catch (error) {
    console.error("Feed fetch API error:", error);
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    );
  }
}
