# Agent Context — Discover

## Purpose

Discover is a personalised RSS news aggregator with a dark-mode "Liquid Glass" UI. It was originally built as a Next.js web dashboard and is being ported to a native SwiftUI app targeting macOS 14+, iPadOS 17+, and iOS 17+. The active development focus is the native app in `macos-app/`. The web dashboard in `discover-dashboard/` serves as the reference implementation.

## Tech Stack

**Native app (primary — `macos-app/`):**
- Language: Swift 6.0
- UI Framework: SwiftUI
- Architecture: Feature-based modules with MVVM pattern
- RSS Parsing: Native `XMLParser` (no external dependencies)
- Concurrency: Swift Actors (`RSSFetcherActor`, `OGImageActor`)
- Target: macOS 14+, iPadOS 17+, iOS 17+ (iOS target pending — see `docs/IOS_TARGET_SETUP.md`)
- Build system: Xcode (project file at `macos-app/Discover.xcodeproj`)

**Web dashboard (reference — `discover-dashboard/`):**
- Framework: Next.js 15.1.0 (App Router), TypeScript
- Styling: Tailwind CSS + custom CSS (glassmorphism)
- RSS: `rss-parser` npm package
- State: React Context + localStorage
- Run: `cd discover-dashboard && npm run dev`

## Entry Points

- **Native app:** `macos-app/Discover/App/DiscoverApp.swift` → `ContentView.swift`
- **Web dashboard:** `discover-dashboard/app/page.tsx` (SSR entry) → `app/layout.tsx` (shell)
- **API route:** `discover-dashboard/app/api/feeds/route.ts` (refresh endpoint)

## Where Business Logic Lives

**Native app (`macos-app/Discover/`):**
- `Core/Models/` — Data models: `ArticleModel.swift`, `CategoryModel.swift`, `FeedModel.swift`
- `Core/Parsing/` — RSS XML parsing (`RSSParser.swift`) and thumbnail extraction (`ThumbnailExtractor.swift`)
- `Core/Services/` — Network layer: `RSSFetcherActor.swift` (fetches feeds), `OGImageActor.swift` (scrapes Open Graph images as fallback)
- `Core/Utilities/` — `HTMLStripper.swift`, `IDGenerator.swift` (djb2 hashing), `SnippetTruncator.swift`, `URLNormaliser.swift`
- `Data/DefaultFeeds.swift` — Hardcoded default RSS feeds and category definitions
- `Features/` — Each feature has its own folder with View + ViewModel pairs

**Web dashboard (`discover-dashboard/`):**
- `lib/feeds.ts` — Default category and feed arrays
- `lib/fetchFeeds.ts` — Core fetch pipeline (parallel RSS fetch, dedup, djb2 hashing, cache)
- `lib/cache.ts` — File-system JSON cache with 15-min TTL
- `lib/ogImage.ts` — OG image scraper fallback
- `lib/types.ts` — TypeScript interfaces (Article, FeedConfig, CategoryConfig)

## Where Data Models / Schemas Live

- Native: `macos-app/Discover/Core/Models/` (Swift structs/classes)
- Web: `discover-dashboard/lib/types.ts` (TypeScript interfaces)

## Tests

- Native: `macos-app/DiscoverTests/DiscoverTests.swift` — Single test file, minimal coverage
- Web: No test files present
- Run native tests: Open `macos-app/Discover.xcodeproj` in Xcode → Cmd+U

## Known TODOs and Incomplete Areas

1. **iOS target not yet created** — The Xcode project currently only has a macOS target. An iOS target (`DiscoverMobile`) needs to be created in Xcode's UI. Full step-by-step instructions are in `docs/IOS_TARGET_SETUP.md`.

2. **Test coverage is minimal** — `DiscoverTests.swift` exists but likely contains only boilerplate. Unit tests for RSS parsing, feed fetching, and model logic are needed.

3. **No persistent storage** — The HANDOFF doc recommends SwiftData or CoreData for article storage, read-state tracking, and custom feed persistence. This has not been implemented yet — the app likely holds state in memory only.

4. **Concurrency safety** — The HANDOFF doc flags that the web app's background refresh lacks a mutex lock. The native app uses Swift Actors which helps, but verify there are no race conditions in `RSSFetcherActor`.

5. **OG Image timeout handling** — Flagged as flawed in the web app. The native `OGImageActor` should have proper `URLSession` timeout handling.

6. **No `.gitignore`** at the project root. Consider adding one that covers `.DS_Store`, `node_modules/`, `.next/`, `*.xcuserstate`, and build artifacts.

7. **The `.claude/worktrees/silly-goodall/` directory** is a stale git worktree containing a full duplicate of the web dashboard source plus build cache. It can likely be removed.

## Gotchas

- **Config is split across two codebases.** The web dashboard has its feed config in `discover-dashboard/lib/feeds.ts` and the native app has its own copy in `macos-app/Discover/Data/DefaultFeeds.swift`. Changes to feeds need to be reflected in both if maintaining both versions.

- **The `Latest app/` folder contains a WebView wrapper, not the native SwiftUI app.** `DiscoverPlatform.app` wraps the Next.js dashboard in a native WebView — it is NOT a build of the SwiftUI app from `macos-app/`. Building the actual SwiftUI app requires opening `macos-app/Discover.xcodeproj` in Xcode and building from there.

- **The `_archive/native-app/Discover.swift` file is superseded.** This was an earlier single-file WebView wrapper. All native development has moved to the `macos-app/` Xcode project.

- **`discover-dashboard/_discovery/`** contains reference screenshots of the web UI. These are useful for visual comparison when building the native app.

- **`scripts/build_app.sh`** builds the WebView wrapper (`DiscoverPlatform.app`), not the SwiftUI native app. It expects to be run from the project root and references `native-app/Discover.swift` (now archived).

- **No package manager lockfile consistency.** The dashboard uses `npm` (has `package-lock.json`). If switching to `pnpm`, update accordingly.

- **Xcode user state files** (`xcuserdata/`, `xcuserstate`) are present and should not be committed to version control.
