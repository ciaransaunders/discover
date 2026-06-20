# AGENTS.md — Discover (macOS / iOS SwiftUI app)

Scoped agent instructions for the native app. For repo-wide rules, see `../AGENTS.md`.
The file `CLAUDE.md` in this folder is a superset of this one — both are kept in sync so Codex, Antigravity, and Claude Code see equivalent guidance. If they diverge, `CLAUDE.md` wins and this file should be updated.

---

## What this target is

Native SwiftUI RSS reader. Swift 6 strict concurrency, SwiftData persistence, zero third-party dependencies. Targets macOS 14+ (active) and iOS 17+/iPadOS 17+ (iOS target still needs to be created — see `../docs/IOS_TARGET_SETUP.md`).

## How to build and test

1. Open `Discover.xcodeproj` in Xcode.
2. Scheme: **Discover**, destination: **My Mac**.
3. `Cmd+R` to run. `Cmd+U` for tests.

CLI (local machines only — may fail in sandboxes):
```bash
xcodebuild test -project Discover.xcodeproj -scheme Discover \
  -destination 'platform=macOS' -configuration Debug
```

Tests live in `DiscoverTests/DiscoverTests.swift` with XML fixtures under `DiscoverTests/Fixtures/`.

## Source map

```
Discover/
├── App/                         # @main entry + root shell
│   ├── DiscoverApp.swift
│   └── ContentView.swift        # NavigationSplitView + glass background
├── Core/                        # Business logic (no UI imports)
│   ├── Models/                  # SwiftData @Model: ArticleModel, FeedModel, CategoryModel
│   ├── Parsing/                 # RSSParser (XMLParser delegate), ThumbnailExtractor
│   ├── Services/                # RSSFetcherActor, OGImageActor
│   └── Utilities/               # HTMLStripper, IDGenerator (djb2), SnippetTruncator,
│                                # URLNormaliser, ModelContext+Save
├── Data/
│   └── DefaultFeeds.swift       # Default categories + feeds ("config")
├── Features/                    # One folder per feature, View + ViewModel pairs
│   ├── ArticleCard/             # ArticleCardView, HeroCardView
│   ├── ArticleList/             # ArticleListView, ArticleListViewModel
│   ├── CategorySidebar/
│   ├── FeedManager/
│   └── Preferences/
├── UI/
│   ├── Components/              # CategoryBadge, FaviconImage, GlassCard, TimeAgoText
│   └── Extensions/              # Color+Hex
└── Resources/                   # Assets.xcassets, Discover.entitlements, Info.plist
```

## Conventions

- **File naming:** `[Feature]View.swift`, `[Feature]ViewModel.swift`.
- **New feature:** new folder under `Features/`, View + ViewModel pair.
- **Shared UI** goes in `UI/Components/`. **Extensions** in `UI/Extensions/`.
- **No UIKit** unless there is no SwiftUI equivalent.
- **SF Symbols only** (`Image(systemName:)`) — no raster icons.
- **No third-party dependencies.** Foundation / SwiftUI / SwiftData only.
- **Concurrency:** async work through actors; ViewModels are `@MainActor`; SwiftData stays on `@MainActor`. Mark `Sendable` explicitly.
- **Dark mode only** — do not add light-mode variants.
- **Persistence errors are not silent** — use `ModelContext.saveOrLog(reason:)` (see `Core/Utilities/ModelContext+Save.swift`) or `try` + surfaced alerts, never `try? context.save()`.

## Key design invariants

- **Article IDs** are `djb2(normalisedURL + guid)`. Must stay byte-identical to the TypeScript version in `../discover-dashboard/lib/fetchFeeds.ts` — changing the hash resets every user's read-state.
- **Seeding is idempotent.** `ArticleListView.seedDefaultsIfNeeded()` inserts only missing categories/feeds; never clobber user edits.
- **OG image fallback** runs only for feeds flagged `useOgImage: true` in `DefaultFeeds.swift` (low-quality RSS thumbnail sources like BBC).
- **Category colours** live on `CategoryModel`; badges, sidebar pips, and card accents all pull from there.

## Current state (as of LLM_HANDOFF.md 2026-04-16)

Working:
- SwiftData models and feed-refresh pipeline.
- macOS `NavigationSplitView`, category sidebar, article grid.
- Feed-status banner (offline / per-feed error).
- Mark read/unread with immediate persistence.
- Parser fixture tests for RSS + Atom.

Open items (see `../LLM_HANDOFF.md` "Suggested Next Steps" and `../BUG_REPORT.md`):
- iOS target needs creation in Xcode UI (`../docs/IOS_TARGET_SETUP.md`).
- More parser fixtures (`content:encoded`, `media:thumbnail`, YouTube, bad dates).
- "Retry failed feeds" button.
- Seed a default `general` category.
- Networking `Logger` category.

## Before you change code

1. Skim `../LLM_HANDOFF.md` (dated, tells you the most recent known-good state).
2. Check `../BUG_REPORT.md` to avoid reopening a fixed bug.
3. Read the ViewModel for the feature you're touching before the View — state flow is ViewModel → View.

## Validation (finish-the-task checklist)

- [ ] `xcodebuild` (or Xcode) compiles with no new warnings.
- [ ] `Cmd+U` / `xcodebuild test` passes — add a test if you changed parsing, hashing, or upsert logic.
- [ ] No new third-party dependency introduced.
- [ ] No light-mode styling added.
- [ ] If you changed feed config, the corresponding change is made (or consciously skipped) in `../discover-dashboard/lib/feeds.ts`.
- [ ] If you changed Swift 6 concurrency surfaces, `Sendable` conformance is explicit and no `@unchecked` was added without a comment explaining why.
