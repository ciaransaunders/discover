# Discover iOS App Handoff Document

This document provides a comprehensive overview of the existing **Discover** web dashboard to guide Claude Code in building a native Apple app (SwiftUI) targeting macOS 14+, iPadOS 17+, and iOS 17+.

## Project Overview

**Discover** is a personalized news aggregator application. It fetches and parses RSS feeds from various sources across multiple predefined categories, displaying them in a modern, visually striking "Liquid Glass" (glassmorphism) masonry tile layout.

Key user value propositions include:

*   **Categorised Content:** Articles are tagged and filterable by topics (e.g., AI/ML, Tech, Gaming, UK News, Film).
*   **Visual Focus:** Heavy reliance on article thumbnail images parsed from RSS endpoints or scraped from Open Graph metadata.
*   **Read State Tracking:** Tracks which articles a user has opened, visually dimming them on return.
*   **Feed Management:** Allows users to add custom RSS endpoints and manage existing feeds and categories.
*   **Aesthetic Design:** The UI utilizes dark mode, animated background elements ("orbs"), and varying levels of frosted glass translucency.

## Current Tech Stack

*   **Framework:** Next.js 15.1.0 (App Router)
*   **Language:** TypeScript
*   **Styling:** Tailwind CSS + Vanilla CSS (`globals.css` for custom keyframes and complex backdrop-filters)
*   **RSS Parsing:** `rss-parser` (NPM package)
*   **Data Fetching Strategy:** Server-side fetching with a file-system JSON cache mechanism and a "stale-while-revalidate" background refresh pattern.
*   **State Management:** React Context (`FeedConfigProvider.tsx` and `ReadStateProvider.tsx`) synced with `localStorage` for client-side persistence and hydration.

## Directory Structure

The original Next.js architecture was already highly organized, separating components, lib utilities, and routing as per modern conventions. Minor structural tweaks were deemed mathematically non-beneficial as no unused or legacy files existed.

```text
/discover-dashboard
├── _discovery/           # Screenshotted UI state reference material for Claude Code
├── _original_structure.txt # Text snapshot of original fs architecture
├── app/                  # Next.js App Router Entry Points
│   ├── api/feeds/route.ts # Serverless API route for refetching operations
│   ├── globals.css       # Core styling variables, Liquid Glass utilities, Orb Animations
│   ├── layout.tsx        # App wrapper, injects ambient animated background
│   └── page.tsx          # Main entry page, kicks off SSR fetch
├── components/           # React Presentation & Logic Components
│   ├── ArticleCard.tsx   # Standard grid card for a feed item
│   ├── CategoryTabs.tsx  # Horizontal scrolling filter pills
│   ├── FeedConfigProvider.tsx # LocalStorage sync for user feeds & categories
│   ├── FeedManager.tsx   # Sidebar slide-out panel for Adding/Removing feeds
│   ├── Header.tsx        # Orchestrator component: Title, Actions, Categories logic
│   ├── HeroCard.tsx      # Enlarged "featured" variant for the top article
│   ├── MasonryGrid.tsx   # CSS columns-based masonry layout wrapper
│   └── ReadStateProvider.tsx # LocalStorage sync for clicked article hashes
└── lib/                  # Utilities, Types & Data Fetching
    ├── cache.ts          # File system cache R/W operations
    ├── feeds.ts          # Hardcoded default `categories` and `feeds` arrays
    ├── fetchFeeds.ts     # Core RSS mapping, deduplication, URL normalization, and djb2 hashing
    ├── ogImage.ts        # Fallback raw HTML fetcher to scrape `<meta property="og:image">`
    └── types.ts          # TypeScript interfaces (Article, FeedConfig, CategoryConfig)
```

## Feed Configuration

*   **Location:** The default, curated list of feeds and categories is located in `lib/feeds.ts`.
*   **Structure:** It consists of two exported arrays: `categories` (defining slug, label, and hex color) and `feeds` (defining name, RSS URL, and associating category slug).
*   **Overrides:** Some feeds (like BBC News or Sky News) have a `useOgImage: true` flag. This instructs `lib/fetchFeeds.ts` to utilize `lib/ogImage.ts` to perform a secondary network request and scrape the article's Open Graph image instead of relying on the low-resolution thumbnail often provided in the RSS XML enclosure.
*   **Client Management:** Users can add or remove feeds dynamically at runtime. This state overrides `lib/feeds.ts` and is persisted to `localStorage` via `components/FeedConfigProvider.tsx`.

## UI Architecture

*   **Layout System:** 
    *   A sticky top header (`Header.tsx` wrapper) containing the app title, refresh button, feed manager toggle, and horizontal category pills (`CategoryTabs.tsx`).
    *   The main content area features a featured/latest article displayed prominently as a horizontal `HeroCard.tsx`.
    *   The remaining articles flow sequentially into a CSS-driven multi-column `MasonryGrid.tsx`, populated by standard `ArticleCard.tsx` units.
*   **Theming (Liquid Glass):** 
    *   Defined exclusively inside `app/globals.css`.
    *   The background (`layout.tsx`) features fixed, slowly animating blurred radial gradients (orbs).
    *   Cards (`ArticleCard.tsx`, `HeroCard.tsx`) use `background: rgba(255,255,255,0.06)` combined with `backdrop-filter: blur(20px) saturate(160%)` to act as translucent windows.
    *   Category tags utilize the specific HEX code defined for the category (e.g., Gaming = #ef4444) heavily diluted with opacity for pill backgrounds (`color + "20"`).

## Data Flow

1.  **Initial Load:** `app/page.tsx` calls `fetchAllFeeds()`.
2.  **Fetch Pipeline (`fetchFeeds.ts`):** 
    *   Checks `lib/cache.ts` (JSON file on disk). If fresh (<15 mins), it returns immediately.
    *   If stale, it returns stale data immediately, but kicks off `fetchFresh()` asynchronously.
    *   `fetchFresh()` parallelizes `fetchSingleFeed()` for all RSS endpoints using `rss-parser`.
    *   Articles are parsed, formatted (HTML stripped from descriptions), and assigned a `djb2` hashed ID based on URL + GUID.
    *   If `useOgImage` is true, a secondary fetch is made to scrape the OG image.
    *   Articles are merged, deduplicated, sorted by date, and written to the cache.
3.  **Client Hydration:** The server HTML is delivered. `FeedConfigProvider.tsx` and `ReadStateProvider.tsx` check `localStorage` to see if user settings or read history overwrite the defaults.
4.  **Refresh Action:** Pressing "Refresh" inside `Header.tsx` fires an API call to `app/api/feeds/route.ts` which proxies a hard refetch using the client's currently active custom feed list.

## Known Issues / Flags

*   **Server Cache Concurrency (Critical Logic Flag):** The existing Node.js `fetchFeeds.ts` background refresh branch (`if (cached) { fetchFresh().then(...) }`) lacks a mutex lock. Concurrent requests hitting a stale cache trigger duplicate parallel multi-feed refetches. *SwiftUI Port requirement: Handle background refresh threading properly using Grand Central Dispatch or Swift Concurrency Actors.*
*   **OG Image Scraper (Timeout Flag):** `lib/ogImage.ts` currently fetches raw HTML strings and regex parses for Open Graph data to bypass low-res RSS images. The timeout logic on the stream reader is flawed. *SwiftUI Port requirement: Apple's `LinkPresentation` framework or proper `URLSession` timeout delegate handling is heavily recommended.*
*   **Local Storage Vulnerability:** The Next.js app deserializes `localStorage` settings into app context blindly. *SwiftUI Port requirement: Utilize `UserDefaults` or `CoreData` with proper `@AppStorage` strict typing or Codable conformance to prevent schema crashing.*

## Claude Code Instructions

Your primary mandate is to port this web dashboard to a native Apple platform application.

**Target platforms:** macOS 14+, iPadOS 17+, iOS 17+.
**App Name:** Discover.
**Language & Framework:** Swift and SwiftUI exclusively.

### Required Architecture & Features:

1.  **Native RSS Parsing:** You must ditch `rss-parser` and implement native XML parsing using Swift's `XMLParser` or an established native dependency (e.g., `FeedKit` if necessary, though native `XMLParser` is preferred for zero-dependency builds). 
2.  **Liquid Glass UI (Native):** Translate the Tailwind glass styling to SwiftUI's `Material` background types. Use `.ultraThinMaterial` or `.thinMaterial` layered over a `ZStack` containing moving `MeshGradient` (iOS 18) or complex animated radial `LinearGradient`s to recreate the ambient orb visual.
3.  **Platform Adaptability:** Use `NavigationSplitView` for macOS/iPadOS to handle categories and feed management natively, adapting to a `NavigationStack` or custom sticky header for iOS.
4.  **Grid Layouts:** Recreate the masonry look using staggered `LazyVGrid` alignments, or SwiftUI's new layout API to flow `ArticleCard` views.
5.  **State Persistence:** Replace `lib/cache.ts` and browser `localStorage` entirely. It is highly recommended to use `SwiftData` (or `CoreData`) to store:
    *   The scraped `Article` models with relationship to a `Feed` model.
    *   The persistent "Is Read" state boolean.
    *   User-defined custom feeds and categories.
6.  **OG Fallback System:** Maintain the fallback logic. If an RSS feed has no image or is manually flagged, perform a background `URLSession` data task to parse the `<meta property="og:image">` tags.

### Assets Reference

*   **Icons:** The web app uses inline SVG elements (found in `Header.tsx`, `FeedManager.tsx`). You **MUST** replace all of these with Apple `SFSymbols` (`Image(systemName: "...")`). Key required symbols:
    *   Refresh icon -> `arrow.clockwise`
    *   Settings/Feed Manager icon -> `gearshape` or `slider.horizontal.3`
    *   Close icon -> `xmark`
    *   Trash icon -> `trash`
*   **Favicons:** The web app relies on `https://www.google.com/s2/favicons?domain=...`. Native apps shouldn't rely on this open endpoint directly without caching. Apple's `LinkPresentation` API natively extracts metadata icons, but otherwise, ensure images are cached aggressively using `AsyncImage` combined with a persistent storage cache layer.
*   **Fonts:** Strip out "Inter" UI font references from CSS and rely gracefully on the system default `.font(.title.weight(.bold))` (San Francisco / SF Pro) to maintain the pristine Apple platform aesthetic.
