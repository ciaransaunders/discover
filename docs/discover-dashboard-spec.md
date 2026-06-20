# Discover Dashboard — Product Spec for Claude Code

## Overview

Build a personal news aggregator dashboard inspired by Perplexity's Discover page. This is a **personal daily dashboard** for a single user, running locally on a MacBook with future ambitions for iPad/iPhone access via browser.

**Design philosophy:** Dark-mode, Liquid Glass-inspired UI (frosted glass, backdrop-blur, subtle transparency, fluid feel) with a clean masonry card layout.

---

## Tech Stack

| Layer | Choice | Rationale |
|-------|--------|-----------|
| Framework | **Next.js 14+ (App Router)** | SSR for feed fetching, no CORS issues, fast local dev |
| Styling | **Tailwind CSS 3.4+** | Utility-first, dark mode built-in, rapid prototyping |
| RSS Parsing | **rss-parser** (npm) | Reliable RSS/Atom → JSON conversion |
| State / Read Tracking | **localStorage** | Simple, no backend needed for v1 |
| Package Manager | **pnpm** or **npm** | Either is fine |

---

## Content Categories & Suggested RSS Feeds

Each category should have 1–3 feeds to start. The feed config should be a single file (`lib/feeds.ts`) that's easy to edit.

### Core Categories

| Category | Suggested Feeds |
|----------|----------------|
| **AI / LLMs / ML** | The Verge AI (`https://www.theverge.com/rss/ai-artificial-intelligence/index.xml`), Ars Technica AI (`https://feeds.arstechnica.com/arstechnica/technology-lab`), MIT Tech Review AI (`https://www.technologyreview.com/feed/`) |
| **Tech Industry** | TechCrunch (`https://techcrunch.com/feed/`), The Verge (`https://www.theverge.com/rss/index.xml`), Ars Technica (`https://feeds.arstechnica.com/arstechnica/index`) |
| **Gaming** | IGN (`https://feeds.feedburner.com/ign/all`), Eurogamer (`https://www.eurogamer.net/feed`), Rock Paper Shotgun (`https://www.rockpapershotgun.com/feed`) |
| **Filmmaking / Cinema** | IndieWire (`https://www.indiewire.com/feed/`), No Film School (`https://nofilmschool.com/rss.xml`), Screen Rant (`https://screenrant.com/feed/`) |
| **Chelsea FC** | Chelsea FC Official (`https://www.chelseafc.com/en/rss.xml`), Football London Chelsea (`https://www.football.london/chelsea-fc/?service=rss`), BBC Sport Chelsea (`https://feeds.bbci.co.uk/sport/football/teams/chelsea/rss.xml`) |
| **UK Politics / Current Affairs** | BBC News UK (`https://feeds.bbci.co.uk/news/uk/rss.xml`), The Guardian UK News (`https://www.theguardian.com/uk-news/rss`), Sky News UK (`https://feeds.skynews.com/feeds/rss/uk.xml`) |
| **Science / Space** | NASA Breaking News (`https://www.nasa.gov/rss/dyn/breaking_news.rss`), New Scientist (`https://www.newscientist.com/feed/home/`), Ars Technica Science (`https://feeds.arstechnica.com/arstechnica/science`) |
| **Finance / Markets / Crypto** | CoinDesk (`https://www.coindesk.com/arc/outboundfeeds/rss/`), Financial Times (may need alternative — FT RSS is paywalled), Bloomberg Markets (same caveat) |
| **Lego / Hobbies** | The Brothers Brick (`https://www.brothers-brick.com/feed/`), Brickset (`https://brickset.com/feed`), BrickFanatics (`https://www.brickfanatics.com/feed/`) |
| **Legal Tech / Legal AI** | Artificial Lawyer (`https://www.artificiallawyer.com/feed/`), Legal IT Insider (`https://legaltechnology.com/feed/`), Law.com Legal Tech (`https://www.law.com/legaltechnews/feed/`) |
| **Neuroscience / ADHD Research** | Neuroscience News (`https://neurosciencenews.com/feed/`), ADDitude Magazine (`https://www.additudemag.com/feed/`), PsyPost (`https://www.psypost.org/feed/`) |

> **Note to Claude Code:** Some feeds may be broken, paywalled, or have changed URLs. The app should handle feed fetch failures gracefully (skip broken feeds, show the rest). Include a fallback message per category if no items load. The feed list above is a starting point — the user will test and swap feeds after the prototype is running.

---

## Page Layout

### Structure (Single Page App)

```
┌─────────────────────────────────────────────────────────┐
│  HEADER: "Discover" + Category Filter Tabs              │
│  [All] [AI] [Tech] [Gaming] [Film] [Chelsea] [UK] ...  │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────────────────────────┐  ┌──────────────┐  │
│  │                                 │  │              │  │
│  │     HERO / FEATURED CARD        │  │   SIDEBAR    │  │
│  │     (Latest top story)          │  │  (optional)  │  │
│  │                                 │  │              │  │
│  └─────────────────────────────────┘  └──────────────┘  │
│                                                         │
│  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐           │
│  │  Card  │ │  Card  │ │  Card  │ │  Card  │           │
│  │        │ │        │ │        │ │        │           │
│  └────────┘ │        │ └────────┘ └────────┘           │
│  ┌────────┐ └────────┘ ┌────────┐ ┌────────┐           │
│  │  Card  │ ┌────────┐ │  Card  │ │  Card  │           │
│  │        │ │  Card  │ │        │ │        │           │
│  │        │ └────────┘ └────────┘ │        │           │
│  └────────┘                       └────────┘           │
│                                                         │
│  MASONRY GRID (variable height cards, 3-4 columns)      │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Hero Card
- The most recent article from any feed (or the first article in the selected category)
- Large card spanning ~2/3 width
- Title, snippet, source favicon/name, timestamp
- Optional: thumbnail image if available in the RSS item

### Masonry Grid
- CSS columns approach (Tailwind `columns-1 sm:columns-2 lg:columns-3 xl:columns-4`)
- `break-inside-avoid` on each card
- Cards vary in height based on content

### Category Filter
- Horizontal scrollable tab bar at the top
- "All" shows mixed feed from all categories
- Clicking a category filters to only those feeds
- Active tab should have a Liquid Glass highlight effect

---

## Card Design

Each card represents one RSS item and should include:

```
┌──────────────────────────────┐
│  [Thumbnail image if avail]  │
│                              │
│  Article Title (bold, white) │
│  2-3 line snippet (gray)    │
│                              │
│  ┌──┐  Source Name  · 3h ago │
│  │🔵│  Category badge        │
│  └──┘                        │
└──────────────────────────────┘
```

### Card styling (Liquid Glass-inspired)
- Background: semi-transparent dark (`bg-white/5` or `bg-[#2a2a2a]/80`)
- `backdrop-blur-xl` for frosted glass effect
- Subtle border: `border border-white/10`
- Rounded corners: `rounded-2xl`
- Hover state: slight brightness increase + subtle scale (`hover:bg-white/10 hover:scale-[1.01]`)
- Smooth transition on hover: `transition-all duration-300`
- Box shadow with a slight glow: `shadow-lg shadow-black/20`

### Read state
- Unread: full opacity, white title
- Read: reduced opacity (`opacity-60`), title turns gray
- Clicking a card opens the article in a new tab AND marks it as read
- Read state persists in `localStorage` (store array of article URLs or GUIDs)
- Optional: "Mark all as read" button per category

---

## Liquid Glass Design Language (CSS Interpretation)

Since this is a web app, not native SwiftUI, recreate the *feel* of Liquid Glass:

### Global
- Page background: deep dark (`bg-[#0a0a0a]` or `bg-[#111111]`)
- No harsh borders — use `border-white/10` or `border-white/5`
- Typography: system font stack (`font-sans`) or Inter/SF Pro if available
- Smooth, buttery transitions everywhere (`transition-all duration-300 ease-out`)

### Glass Panels
```css
/* Reusable glass panel class */
.glass {
  background: rgba(255, 255, 255, 0.05);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 16px;
}
```

### Category Tabs
- Inactive: transparent with white/50 text
- Active: glass background with backdrop blur, white text
- Smooth sliding indicator animation between tabs

### Scrollbar
- Thin, semi-transparent custom scrollbar
- Or hide scrollbar entirely for a cleaner look

---

## Data Flow

```
1. User loads page
2. Next.js server component fetches all RSS feeds in parallel
3. Feeds parsed → normalised into common article shape:
   {
     id: string (guid or link hash),
     title: string,
     snippet: string (first 200 chars of content),
     link: string,
     source: string (feed name),
     category: string (from config),
     thumbnail: string | null (from enclosure or media:content),
     publishedAt: Date,
   }
4. Articles sorted by publishedAt (newest first)
5. Client receives articles, renders masonry grid
6. Client checks localStorage for read article IDs
7. On card click → open link + save ID to localStorage read list
```

### Feed Refresh
- For v1: refresh on page reload (no polling)
- Cache feeds for 15 minutes using Next.js `revalidate` or `unstable_cache`
- Nice-to-have for v2: auto-refresh every 15 mins with visual indicator

---

## File Structure

```
discover-dashboard/
├── app/
│   ├── layout.tsx          # Root layout, dark theme, fonts
│   ├── page.tsx            # Main page (server component, fetches feeds)
│   └── globals.css         # Tailwind + glass utility classes
├── components/
│   ├── Header.tsx          # "Discover" title + category tabs
│   ├── CategoryTabs.tsx    # Horizontal scrollable filter tabs
│   ├── HeroCard.tsx        # Large featured article card
│   ├── ArticleCard.tsx     # Standard masonry grid card
│   ├── MasonryGrid.tsx     # Grid container with columns layout
│   └── ReadStateProvider.tsx # Context for localStorage read tracking
├── lib/
│   ├── feeds.ts            # Feed URL config (categories + URLs)
│   ├── fetchFeeds.ts       # RSS fetching + normalisation logic
│   └── types.ts            # TypeScript interfaces
├── tailwind.config.ts
├── package.json
└── README.md
```

---

## Responsive Behaviour

| Breakpoint | Columns | Notes |
|------------|---------|-------|
| Mobile (<640px) | 1 column | Full width cards, no hero |
| Tablet (640-1024px) | 2 columns | Hero spans full width |
| Desktop (1024-1280px) | 3 columns | Hero spans 2 columns |
| Large (1280px+) | 4 columns | Hero spans 2-3 columns |

---

## What's NOT in v1

- No AI summarisation (RSS snippets are sufficient)
- No user accounts or authentication
- No database (localStorage only)
- No bookmarking / save for later
- No weather or market widgets (defer to v2)
- No search within articles
- No deployment (localhost:3000 only)

---

## Getting Started (for Claude Code)

```bash
# Create the project
npx create-next-app@latest discover-dashboard --typescript --tailwind --app --src-dir=false

# Install dependencies
cd discover-dashboard
npm install rss-parser

# Run dev server
npm run dev
```

Then build out the components following the structure above. Start with:
1. Feed config + fetch logic
2. Basic page rendering all articles
3. Masonry grid layout
4. Card styling with Liquid Glass effects
5. Category filtering (client-side)
6. Read state tracking
7. Hero card
8. Polish and responsive tweaks

---

## Reference Screenshots

The user has provided 3 screenshots of Perplexity's Discover page showing:
1. A hero/featured story card (Nvidia + OpenAI deal) with large title, snippet, source badges, and article image
2. Mixed masonry grid with headline cards (Amazon/Walmart), medium cards (AMD, UK banks, OpenAI alignment), and a featured story (Sentient Foundation)
3. Full page layout showing: category navigation at top ("For You", "Top", "Topics"), hero story, card grid, and right sidebar with weather, market data (S&P, NASDAQ, Bitcoin, VIX), and trending companies

The prototype should match this visual density and information hierarchy.
