# AGENTS.md — Discover (Next.js web dashboard)

Scoped agent instructions for the **reference** Next.js implementation. For repo-wide rules, see `../AGENTS.md`. For the active SwiftUI port, see `../macos-app/AGENTS.md`.

This sub-project is the **original** version of Discover. The native app in `../macos-app/` is the active development target. Treat this dashboard as:
- A working reference for what the feature set should look like.
- A design reference for the "Liquid Glass" UI (see `_discovery/` screenshots).
- A source of truth for the fetch/dedup/hash pipeline (`lib/fetchFeeds.ts`).

Only make changes here if the task is explicitly about the web dashboard, or if you are keeping `lib/feeds.ts` in sync with the native app's `DefaultFeeds.swift`.

---

## Stack

- Next.js 15 (App Router), React 19, TypeScript 5.
- Tailwind CSS + custom glassmorphism CSS.
- `rss-parser` (npm) for RSS.
- State: React Context + `localStorage` (no database).
- File-system JSON cache with 15-minute TTL (`lib/cache.ts`).

## Run / build / lint

```bash
npm install
npm run dev        # http://localhost:3000
npm run build      # production build
npm start          # serve built app
npm run lint       # next lint
```

No test script defined — there are no web tests.

## Source map

```
discover-dashboard/
├── app/
│   ├── layout.tsx               # shell
│   ├── page.tsx                 # SSR entry
│   └── api/feeds/route.ts       # refresh endpoint
├── components/                  # React components: ArticleCard, HeroCard, Header, etc.
├── lib/
│   ├── feeds.ts                 # default categories + feeds (MIRROR of DefaultFeeds.swift)
│   ├── fetchFeeds.ts            # parallel fetch, dedup, djb2 hashing, cache
│   ├── cache.ts                 # 15-min TTL file cache
│   ├── ogImage.ts               # OG image scraper fallback
│   └── types.ts                 # TS interfaces: Article, FeedConfig, CategoryConfig
├── _discovery/                  # UI reference screenshots — do not delete
└── package.json
```

## Invariants

- **djb2 hash in `lib/fetchFeeds.ts` must match** the Swift `IDGenerator.swift` exactly. If you change hashing, update both.
- **Feed/category config in `lib/feeds.ts` mirrors** `../macos-app/Discover/Data/DefaultFeeds.swift`. When editing one, consider whether the other needs the same change.
- **Cache TTL is 15 minutes.** Don't lower it casually — feeds rate-limit.
- **OG image fallback** applies only when a feed's `useOgImage` flag is true.

## What not to touch

- `.next/`, `node_modules/`, `.npm-cache/`, `tsconfig.tsbuildinfo` — build/tool artifacts.
- `_discovery/` — reference screenshots used by native-app work.
- `_original_structure.txt` — historical snapshot.

## Validation checklist

- [ ] `npm run build` succeeds.
- [ ] `npm run lint` is clean (or only reports pre-existing issues).
- [ ] If feed config changed, `../macos-app/Discover/Data/DefaultFeeds.swift` was updated (or the task scope explicitly excludes it).
- [ ] If hashing changed, both implementations were updated.
