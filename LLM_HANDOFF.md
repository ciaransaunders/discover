# Discover (macOS SwiftUI) — LLM Handoff

Date: 2026-04-16
Workspace: `/Users/ciaran/Desktop/VIBE CODING/NEWS PORJECT copy`
Primary app project: `/Users/ciaran/Desktop/VIBE CODING/NEWS PORJECT copy/macos-app/Discover.xcodeproj`

This repo is a bit of a “monorepo-ish” workspace (there’s also `discover-dashboard/` and other experiments), but the current native macOS app lives under `macos-app/Discover`.

## What This App Is

Discover is a native SwiftUI RSS reader with a “Liquid Glass” look. It stores feeds, categories, and articles in SwiftData, refreshes feeds concurrently via actors, and renders a hero card + masonry grid of article cards.

If you need higher-level product/architecture context, start with:
- `/Users/ciaran/Desktop/VIBE CODING/NEWS PORJECT copy/macos-app/CLAUDE.md` (most relevant instructions + structure)
- `/Users/ciaran/Desktop/VIBE CODING/NEWS PORJECT copy/docs/HANDOFF.md` (older broader handoff/spec)

## Current State (What Works)

- SwiftData models exist: `ArticleModel`, `FeedModel`, `CategoryModel` under `macos-app/Discover/Core/Models/`.
- Feed refresh pipeline:
  - `ArticleListViewModel` (MainActor) snapshots enabled `FeedModel` rows into `FeedDescriptor`
  - `RSSFetcherActor` fetches feeds concurrently and parses with `RSSParser`
  - ViewModel upserts parsed items into `ArticleModel`, updates per-feed `lastFetchedAt` and `lastError`
- UI:
  - macOS uses `NavigationSplitView` with `CategorySidebarView` + `ArticleListView`
  - `ArticleListView` shows a feed-status banner if feeds failed or if the app is offline
  - Cards (`HeroCardView`, `ArticleCardView`) support open/share/copy and mark read/unread

## Recent Improvements Added (This Session)

### Parser fixtures + tests

- Added real XML fixtures:
  - `/Users/ciaran/Desktop/VIBE CODING/NEWS PORJECT copy/macos-app/DiscoverTests/Fixtures/rss_sample.xml`
  - `/Users/ciaran/Desktop/VIBE CODING/NEWS PORJECT copy/macos-app/DiscoverTests/Fixtures/atom_sample.xml`
- Added fixture-based tests that load resources from the test bundle:
  - `/Users/ciaran/Desktop/VIBE CODING/NEWS PORJECT copy/macos-app/DiscoverTests/DiscoverTests.swift`
- Updated Xcode project so those fixtures are included as test resources:
  - `/Users/ciaran/Desktop/VIBE CODING/NEWS PORJECT copy/macos-app/Discover.xcodeproj/project.pbxproj`

### Safer seeding + error surfacing

- `ArticleListView.seedDefaultsIfNeeded()` now:
  - Inserts only missing categories/feeds (idempotent, preserves user edits)
  - Uses `try` + UI alert instead of silently ignoring `modelContext.save()` failures
  - File: `/Users/ciaran/Desktop/VIBE CODING/NEWS PORJECT copy/macos-app/Discover/Features/ArticleList/ArticleListView.swift`

### Offline / feed failed UI

- `ArticleListView` now queries `FeedModel` and renders a banner when:
  - All enabled feeds are failing with `Offline` (wifi slash)
  - Some feeds have `lastError` (warning triangle) + quick “Feeds” button
  - File: `/Users/ciaran/Desktop/VIBE CODING/NEWS PORJECT copy/macos-app/Discover/Features/ArticleList/ArticleListView.swift`
- `RSSFetcherActor` maps common `URLError` codes to short, stable messages (including `Offline`) so the UI can reason reliably:
  - File: `/Users/ciaran/Desktop/VIBE CODING/NEWS PORJECT copy/macos-app/Discover/Core/Services/RSSFetcherActor.swift`

### Parser diagnostics

- `RSSParser` gained `parseWithDiagnostics(...) -> (items, parserError)`:
  - Helps distinguish empty feeds vs parse failures
  - File: `/Users/ciaran/Desktop/VIBE CODING/NEWS PORJECT copy/macos-app/Discover/Core/Parsing/RSSParser.swift`
- `RSSFetcherActor` treats “items empty + parserError present” as `Parse failed: ...`.

### Better persistence diagnostics

- Added `ModelContext.saveOrLog(reason)` to avoid silent save failures in UI code:
  - File: `/Users/ciaran/Desktop/VIBE CODING/NEWS PORJECT copy/macos-app/Discover/Core/Utilities/ModelContext+Save.swift`
- Wired into:
  - `/Users/ciaran/Desktop/VIBE CODING/NEWS PORJECT copy/macos-app/Discover/Features/ArticleCard/ArticleCardView.swift`
  - `/Users/ciaran/Desktop/VIBE CODING/NEWS PORJECT copy/macos-app/Discover/Features/ArticleCard/HeroCardView.swift`
- Added to Xcode project sources via:
  - `/Users/ciaran/Desktop/VIBE CODING/NEWS PORJECT copy/macos-app/Discover.xcodeproj/project.pbxproj`

### Feed Manager polish

- Feed sections now sort by `CategoryModel.priority` and show the category *label* instead of slug when possible.
- Feed rows show `lastError` (orange) or `lastFetchedAt` (relative time) if available.
- `FeedManagerViewModel` now surfaces save failures (no `try? context.save()`).
- Files:
  - `/Users/ciaran/Desktop/VIBE CODING/NEWS PORJECT copy/macos-app/Discover/Features/FeedManager/FeedManagerView.swift`
  - `/Users/ciaran/Desktop/VIBE CODING/NEWS PORJECT copy/macos-app/Discover/Features/FeedManager/FeedManagerViewModel.swift`

## Known Environment / Tooling Issues

In this Codex sandbox environment, `xcodebuild` fails due to Swift macro expansion (`swift-plugin-server` malformed response) affecting:
- SwiftData macros (`@Model`, `@Query`)
- Observation macros (`@Observable`)

This is an environment limitation, not necessarily a project issue. Verify builds/tests via Xcode locally.

Also note: this folder is not the git repo root. `git rev-parse --show-toplevel` resolves to `/Users/ciaran/Desktop`.

## How To Run / Test (On a Normal macOS Dev Setup)

1. Open `/Users/ciaran/Desktop/VIBE CODING/NEWS PORJECT copy/macos-app/Discover.xcodeproj` in Xcode.
2. Select scheme `Discover` and destination `My Mac`.
3. Run with Cmd+R.
4. Run tests with Cmd+U.

Optional CLI (if your environment allows it):
- `xcodebuild test -project macos-app/Discover.xcodeproj -scheme Discover -destination 'platform=macOS' -configuration Debug`

## Code Map (Where Things Live)

- App entry: `/Users/ciaran/Desktop/VIBE CODING/NEWS PORJECT copy/macos-app/Discover/App/DiscoverApp.swift`
- Root shell: `/Users/ciaran/Desktop/VIBE CODING/NEWS PORJECT copy/macos-app/Discover/App/ContentView.swift`
- Sidebar: `/Users/ciaran/Desktop/VIBE CODING/NEWS PORJECT copy/macos-app/Discover/Features/CategorySidebar/CategorySidebarView.swift`
- Main list + seeding + status banner: `/Users/ciaran/Desktop/VIBE CODING/NEWS PORJECT copy/macos-app/Discover/Features/ArticleList/ArticleListView.swift`
- Refresh/upsert logic: `/Users/ciaran/Desktop/VIBE CODING/NEWS PORJECT copy/macos-app/Discover/Features/ArticleList/ArticleListViewModel.swift`
- Network fetch actor: `/Users/ciaran/Desktop/VIBE CODING/NEWS PORJECT copy/macos-app/Discover/Core/Services/RSSFetcherActor.swift`
- Parser: `/Users/ciaran/Desktop/VIBE CODING/NEWS PORJECT copy/macos-app/Discover/Core/Parsing/RSSParser.swift`
- Thumbnail heuristics: `/Users/ciaran/Desktop/VIBE CODING/NEWS PORJECT copy/macos-app/Discover/Core/Parsing/ThumbnailExtractor.swift`
- OG image actor: `/Users/ciaran/Desktop/VIBE CODING/NEWS PORJECT copy/macos-app/Discover/Core/Services/OGImageActor.swift`
- Seed config: `/Users/ciaran/Desktop/VIBE CODING/NEWS PORJECT copy/macos-app/Discover/Data/DefaultFeeds.swift`
- Tests: `/Users/ciaran/Desktop/VIBE CODING/NEWS PORJECT copy/macos-app/DiscoverTests/DiscoverTests.swift`

## Suggested Next Steps (High Value)

- Add more fixture cases:
  - Namespaces edge cases (`content:encoded`, Atom `link rel="alternate"` variations)
  - `media:thumbnail`, YouTube feeds, invalid dates
- Improve per-feed error UX:
  - Add a “Retry failed feeds” button (filter by `lastError != nil`)
  - Store last HTTP status separately (optional)
- Make “General” category first-class:
  - Seed a `general` category by default (currently not in `DefaultFeeds.categories`)
  - Ensure all feeds always point to a valid category row
- Add a lightweight `Logger` category for networking (`RSSFetcherActor`, `OGImageActor`)

## Conventions / Constraints

- Keep the app dependency-free (Foundation/SwiftUI only).
- Prefer actors for async work; keep SwiftData usage on `@MainActor`.
- Dark mode only (per `macos-app/CLAUDE.md`).

