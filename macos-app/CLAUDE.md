# CLAUDE.md — Agent Instructions for Discover (Xcode Project)

## What This Project Is

Discover is a personalised RSS news aggregator with a dark-mode "Liquid Glass" glassmorphism UI. It fetches RSS feeds across curated categories (AI, Tech, Gaming, Film, Chelsea FC, UK News, Science, Finance, Lego, Legal Tech, Neuroscience) and displays them in a masonry card layout. Originally a Next.js web app, it is being ported to a native SwiftUI app. This Xcode project (`Discover.xcodeproj`) is the primary codebase.

## Tech Stack

- **Language:** Swift 6.0 (strict concurrency)
- **UI:** SwiftUI (no UIKit unless platform-specific adaptation requires it)
- **Architecture:** Feature-based MVVM — each feature has its own folder with View + ViewModel pairs
- **RSS Parsing:** Native `XMLParser` — zero external dependencies
- **Concurrency:** Swift Actors (`RSSFetcherActor`, `OGImageActor`) for thread-safe network operations
- **Targets:** macOS 14+ (existing), iOS 26+ (pending creation — see below)
- **No SPM dependencies** — the project is intentionally dependency-free

## Project Structure

```
Discover/
├── App/                          # Entry point
│   ├── DiscoverApp.swift         #   @main App struct, WindowGroup setup
│   └── ContentView.swift         #   Root view — NavigationSplitView shell
├── Core/                         # Business logic (no UI imports)
│   ├── Models/                   #   Data structs
│   │   ├── ArticleModel.swift    #     Article: id, title, url, snippet, image, date, category, isRead
│   │   ├── CategoryModel.swift   #     Category: slug, label, hex color
│   │   └── FeedModel.swift       #     Feed: name, url, categorySlug, useOgImage flag
│   ├── Parsing/                  #   RSS XML handling
│   │   ├── RSSParser.swift       #     XMLParser delegate — extracts items from RSS/Atom XML
│   │   └── ThumbnailExtractor.swift  # Extracts image URLs from media:content, enclosure, etc.
│   ├── Services/                 #   Network layer (actors)
│   │   ├── RSSFetcherActor.swift #     Fetches all feeds in parallel, deduplicates, hashes IDs (djb2)
│   │   └── OGImageActor.swift    #     Fallback: scrapes <meta property="og:image"> from article HTML
│   └── Utilities/                #   Pure helper functions
│       ├── HTMLStripper.swift    #     Strips HTML tags from RSS description text
│       ├── IDGenerator.swift     #     djb2 hash function for deterministic article IDs
│       ├── SnippetTruncator.swift #    Truncates article snippets to a max length
│       └── URLNormaliser.swift   #     Normalises URLs for dedup comparison
├── Data/
│   └── DefaultFeeds.swift        # Hardcoded default feeds + categories (the "config file")
├── Features/                     # Feature modules (View + ViewModel)
│   ├── ArticleCard/
│   │   ├── ArticleCardView.swift #     Standard masonry grid card
│   │   └── HeroCardView.swift    #     Large featured card for top story
│   ├── ArticleList/
│   │   ├── ArticleListView.swift #     Main scrollable article grid
│   │   └── ArticleListViewModel.swift  # Manages fetch state, filtering, refresh
│   ├── CategorySidebar/
│   │   └── CategorySidebarView.swift   # Sidebar with category filter list
│   ├── FeedManager/
│   │   ├── FeedManagerView.swift #     Sheet/popover for adding/removing feeds
│   │   └── FeedManagerViewModel.swift  # Feed CRUD operations
│   └── Preferences/
│       └── PreferencesView.swift #     App preferences/settings
├── UI/                           # Shared UI building blocks
│   ├── Components/
│   │   ├── CategoryBadge.swift   #     Coloured pill showing category label
│   │   ├── FaviconImage.swift    #     Async-loaded favicon for feed sources
│   │   ├── GlassCard.swift       #     Reusable glassmorphism card container
│   │   └── TimeAgoText.swift     #     "2h ago" relative timestamp display
│   └── Extensions/
│       └── Color+Hex.swift       #     Color init from hex string
└── Resources/
    ├── Assets.xcassets           # App icons and colour assets
    ├── Discover.entitlements     # macOS sandbox entitlements (network client)
    └── Info.plist                # App metadata
```

## How to Build & Run

1. Open `Discover.xcodeproj` in Xcode
2. Select the **Discover** scheme and a macOS destination
3. Press `Cmd+R` to build and run
4. The app fetches RSS feeds on launch and displays them in the masonry grid

To run tests: `Cmd+U` (tests are in `DiscoverTests/DiscoverTests.swift` — currently minimal)

## Key Design Decisions

**Article ID generation:** Articles are identified by a djb2 hash of their normalised URL + GUID. This matches the web dashboard's ID scheme for potential future cross-platform sync. See `IDGenerator.swift`.

**Image strategy:** RSS feeds provide images via `media:content`, `media:thumbnail`, or `enclosure` tags (handled by `ThumbnailExtractor.swift`). Feeds flagged with `useOgImage: true` in `DefaultFeeds.swift` trigger a secondary HTML fetch to scrape the Open Graph meta image instead — this is for sources like BBC News that provide low-res RSS thumbnails. See `OGImageActor.swift`.

**Category colours:** Each category has a hex colour defined in `CategoryModel`. These are used for badge backgrounds, sidebar indicators, and card accent colours. The mapping lives in `DefaultFeeds.swift`.

**Glass UI:** Cards use SwiftUI `.ultraThinMaterial` or `.thinMaterial` over animated gradient backgrounds. The "Liquid Glass" look requires a colourful animated `ZStack` behind the content — check `ContentView.swift` for the background implementation.

## Conventions to Follow

- **File naming:** `[Feature]View.swift`, `[Feature]ViewModel.swift` — always suffix with View/ViewModel
- **New features:** Create a new folder under `Features/` with its own View + ViewModel pair
- **Shared UI:** Reusable components go in `UI/Components/`. Extensions go in `UI/Extensions/`
- **Models:** All data structs in `Core/Models/`. Keep them `Codable`, `Identifiable`, `Hashable`
- **No UIKit:** Use SwiftUI exclusively unless there is no SwiftUI equivalent
- **SF Symbols only:** All icons must use `Image(systemName:)` — no custom icon assets
- **No third-party dependencies:** The project is intentionally zero-dependency. Use Foundation/SwiftUI built-ins
- **Strict concurrency:** All async work goes through actors. Use `@MainActor` for ViewModels. Mark `Sendable` conformance explicitly
- **Dark mode only:** The app does not support light mode. All colours should be designed for dark backgrounds

## What Needs to Be Done

### Critical — iOS Target

An iOS target (`DiscoverMobile`) has not yet been created. This **must be done in Xcode's UI** — you cannot edit `project.pbxproj` while Xcode has the project open. Full instructions are in `../docs/IOS_TARGET_SETUP.md`. Summary:

1. File > New > Target > iOS > App → name it `DiscoverMobile`, bundle ID `com.discover.app.mobile`
2. Add all existing Swift files + Assets.xcassets to the new target's membership
3. Set iOS deployment target to 26.0, Swift Language Version to 6.0
4. Delete the auto-generated `DiscoverMobile/` folder (we share source files across targets)

After creating the target, you may need `#if os(iOS)` / `#if os(macOS)` conditionals in places where the UI diverges (e.g., `NavigationSplitView` column behaviour, toolbar placement).

### High Priority — Persistent Storage

The app currently holds all state in memory. It needs:

- **SwiftData** (preferred) or CoreData for persisting articles, read-state, and custom feeds
- `@Model` classes for `Article`, `Feed`, `Category` (or keep the current structs and add a SwiftData layer)
- Read-state tracking: store which article IDs the user has opened, persist across launches
- Custom feed persistence: user-added feeds should survive app restarts

### High Priority — Tests

`DiscoverTests/DiscoverTests.swift` contains minimal boilerplate. Needed:

- Unit tests for `RSSParser` (feed it known XML, verify parsed output)
- Unit tests for `IDGenerator` (verify djb2 hash determinism)
- Unit tests for `HTMLStripper`, `URLNormaliser`, `SnippetTruncator`
- Integration test for `RSSFetcherActor` (mock URLSession, verify dedup + parallel fetch)
- UI tests for basic navigation (launch → see articles → tap category → filter works)

### Medium Priority — Concurrency & Error Handling

- Verify `RSSFetcherActor` has no race conditions during concurrent refresh
- Add proper `URLSession` timeout configuration to `OGImageActor` (the web app's equivalent had flawed timeout logic)
- Add user-facing error states: "No internet", "Feed unavailable", "No articles in this category"
- Add pull-to-refresh on iOS, toolbar refresh button on macOS

### Medium Priority — Platform Adaptation

- macOS: `NavigationSplitView` with category sidebar + article grid. Window should support resizing
- iOS: Bottom tab bar or horizontal category pills at top. Cards should be single-column on iPhone, multi-column on iPad
- Shared: Use `#if os()` sparingly — prefer adaptive layout using `GeometryReader` or `horizontalSizeClass`

### Low Priority — Polish

- Background auto-refresh on a timer (every 15 mins, matching the web app's cache TTL)
- Animate article loading (skeleton cards or shimmer effect)
- "Mark all as read" action
- Search/filter within current articles
- Haptic feedback on iOS for pull-to-refresh and card interactions

## Reference Material

- **Web dashboard source:** `../discover-dashboard/` — the TypeScript reference implementation. Check `lib/fetchFeeds.ts` for the fetch pipeline logic, `lib/feeds.ts` for the complete feed/category config, and `components/` for UI patterns
- **UI screenshots:** `../discover-dashboard/_discovery/` — screenshots of the web app showing the target visual design
- **Product spec:** `../docs/discover-dashboard-spec.md` — original product requirements
- **Handoff doc:** `../docs/HANDOFF.md` — comprehensive porting guide with architecture decisions, known issues, and feature requirements
- **iOS setup steps:** `../docs/IOS_TARGET_SETUP.md` — step-by-step Xcode UI instructions for creating the iOS target
- **App icon:** `../assets/discover_app_icon.png` — 1024px source PNG

## Gotchas

1. **Feed config lives in two places.** `DefaultFeeds.swift` (this project) and `../discover-dashboard/lib/feeds.ts` (web app). If you add or change feeds, consider whether both need updating.

2. **The `Latest app/` folder in the project root contains a WebView wrapper, NOT a build of this SwiftUI app.** It's a legacy approach where a native shell loaded the Next.js dashboard in a WKWebView. Ignore it for development purposes.

3. **The `_archive/native-app/Discover.swift` is completely superseded.** That was the single-file WebView wrapper. This Xcode project replaced it entirely.

4. **`scripts/build_app.sh` does NOT build this project.** It built the old WebView wrapper. To build this app, use Xcode (`Cmd+B`).

5. **No `.gitignore` at the project root.** If you initialise version control, add ignores for `.DS_Store`, `xcuserdata/`, `*.xcuserstate`, `DerivedData/`, `build/`, `.swiftpm/`, `node_modules/`, and `.next/`.

6. **Entitlements:** `Discover.entitlements` grants `com.apple.security.network.client` for outbound network access. If you add new capabilities (e.g., App Groups for sharing data with a widget), update the entitlements file.

7. **The djb2 hash in `IDGenerator.swift` must produce identical results to the JavaScript version** in `../discover-dashboard/lib/fetchFeeds.ts`. If you change the hashing, articles will get new IDs and read-state will reset.

## Recent Changes (2026-03-12)

- Polished macOS article and hero cards with an unread indicator, softer read-state dimming, refined typography spacing, and a thumbnail gradient scrim.
- Added macOS-only hover lift/shadow on cards to improve interactivity cues.
- Ensured read/unread toggles from the context menu persist immediately for both hero and standard cards.
