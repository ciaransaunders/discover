# BUG REPORT — Discover Project

## Phase 2 — bug-finder & eliminator sweep (2026-06-20) ✅

**Method:** clean build with warnings treated as errors (`SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`,
`GCC_TREAT_WARNINGS_AS_ERRORS=YES`) → **0 warnings**; then a 6-dimension parallel audit
(concurrency/actor-isolation, force-unwraps/crashes, retain-cycles & resource lifecycle, SwiftData,
SwiftUI state, dead-code) of the new Phase-1 code, **each finding adversarially verified** by an
independent agent. **15 issues raised → 4 confirmed real**; 11 were rejected as false alarms by the
verify pass — notably an overstated "duplicate upserts / data corruption in multi-window" claim that
was disproven (the upsert path is `@MainActor`, has no suspension point, and is idempotent by djb2
id, so concurrent loops insert zero duplicate rows). All 4 confirmed issues were fixed:

| # | Severity | Location | Defect | Fix |
|---|---|---|---|---|
| S1 | medium | `ContentView` / `RefreshScheduler` | The background-refresh loop was an unstructured `Task` owned **per-window** via `@State`; SwiftUI never cancelled it on window close and the `[weak self]` was promoted to a strong `self`, so closing any secondary window leaked the scheduler + its view-model + the window's `ModelContext`, and the orphaned loop kept firing network fetches into a torn-down context. | Made `RefreshScheduler` a **single app-lifetime instance** owned by `DiscoverApp` and injected via `.environment`; `start(context:)` is restart-safe, so each window re-arms the one shared loop instead of creating its own. |
| S2 | low | same | N windows ran N concurrent refresh loops (redundant network; data layer already safe). | Same single-shared-instance change → exactly one loop app-wide. |
| S3 | low | `OGImageActor` | On exceeding 500 entries the cache cleared **entirely** (`removeAll`), thrashing ~500 still-useful entries and forcing redundant ≤50 KB HTML re-scrapes. | Bounded **FIFO eviction** — drop only the oldest overflow, keep the rest. |
| S4 | low | `RefreshScheduler` | Unused `import OSLog` (dead code). | Removed. |

**Cluster G (Safari extension) de-scoped** by the owner ("Skip G"). The uncommitted G2/G3 App-Group
inbox scaffolding (`AppGroup`, `PendingFeed`, `PendingFeedInbox`, `SharedFeedImporter` + wiring/tests)
was removed so no dead, non-functional App-Group code remains in a bug-*elimination* phase.

**Final gate:** clean build with **0 warnings / 0 errors**; full Swift Testing suite green on **two
consecutive runs** (`TEST SUCCEEDED`, 0 failures both times); **no crash on launch** (app launched
from the built bundle, stayed alive, crash-report delta = 0).

**AppleScript verification (goal "How to verify"):** the `.sdef` **loads** (`sdef Discover.app`
emits the full dictionary; `OSAScriptingDefinition` + `NSAppleScriptEnabled` set in Info.plist;
`SdefValidationTests` green) and both the **command** (`refresh feeds`) and **property**
(`unread count` / `article count`) terminology **resolve via `osascript`/`osacompile`** when our
build is the registered `com.discover.app` handler. (Diagnostic note: terminology initially appeared
to fail only because several **stale `com.discover.app` builds** were registered with LaunchServices
and won name resolution — not an sdef defect; **no sdef change was required**.) Runtime command
execution returns `-1743` only because the macOS **Automation (TCC) consent** for controlling the
app cannot be granted in a non-interactive shell — a one-time user approval, not a code issue.

## Performance / image quality (2026-06-20, from live-app feedback) 🟠

User observed the running app was "very slow" and "some pictures pulled are very low res".

| # | Location | Defect | Fix |
|---|---|---|---|
| P1 | `ArticleCardView`, `HeroCardView`, `FaviconImage` | All images used SwiftUI `AsyncImage`, which does **not cache decoded images**. In the `LazyVGrid` masonry every card re-downloaded + re-decoded its thumbnail **and** a per-card Google favicon every time it scrolled back into view → the dominant cause of jank. | New `ImageLoader` actor: size-capped `NSCache` of decoded images, on-disk `URLCache`, in-flight de-duplication. New `CachedAsyncImage` drop-in used by both cards + favicon. |
| P2 | image decode path | Full-size originals were decoded at full resolution into a 160pt card (wasted CPU/memory). | `ImageLoader` downsamples via ImageIO `CGImageSourceCreateThumbnailAtIndex` to the display size. |
| P3 | `ThumbnailExtractor` / feeds without `useOgImage` | Low-res `media:thumbnail` images were upscaled to fill the card → blurry (e.g. BBC). High-res `og:image` upgrade only ran for flagged feeds. | New `ImageURLUpgrader` (conservative, signature-safe): bumps BBC iChef width path segment to `/976/` and strips WordPress `-WxH` resize suffixes; applied at display so existing stored articles benefit. Does **not** touch query-signed CDNs (e.g. Guardian). |

## Phase 0 — Baseline build/test repair (2026-06-20) 🟥 BLOCKER

`main` did **not** compile and the test target had **never run**. Eight distinct pre-existing
defects were fixed to re-establish a green baseline before any feature work. After these fixes:
`xcodebuild … build` → **BUILD SUCCEEDED** (0 warnings, 0 errors); `xcodebuild … test` →
**TEST SUCCEEDED** (12/12 passing).

| # | Location | Defect | Fix |
|---|---|---|---|
| B1 | `Discover.xcodeproj/project.pbxproj` | `AppLogger.swift` existed on disk but was **not a member of the Discover target** → `Logger.networking`/`.parsing`/`.ui`/`.persistence` undefined; ~15 compile errors across `RSSFetcherActor`/`RSSParser`. | Added the file to the target (PBXBuildFile + PBXFileReference + Utilities group + Sources phase). |
| B2 | `Core/Utilities/ModelContext+Save.swift` | Local `private extension Logger { static let persistence }` collided with the canonical one in `AppLogger.swift` once it compiled → *invalid redeclaration*. | Removed the duplicate; use the canonical `Logger.persistence`. |
| B3 | `Features/ArticleList/ArticleListView.swift` | `feedStatusBanner` used `guard … else { EmptyView(); return }` inside a `@ViewBuilder` (illegal) → *non-void function should return a value*. | Restructured to an `if !failedFeeds.isEmpty { … }` block. |
| B4 | `Features/ArticleList/ArticleListView.swift` | `.foregroundStyle(isOffline ? .secondary : .orange)` mixed `HierarchicalShapeStyle` and `Color` in one ternary → type error. | Unified both branches to `Color` (`Color.secondary` / `Color.orange`). |
| B5 | `DiscoverTests/DiscoverTests.swift` | Used `Data`/`Bundle`/`URL` with only `import Testing` → *cannot find type 'Data' in scope*. | Added `import Foundation`. |
| B6 | `DiscoverTests/DiscoverTests.swift` | `loadFixture`/`FixtureError` were `private` to `RSSParserFixtureTests` but called from `UtilityTests` → *cannot find 'loadFixture' in scope*. | Hoisted both to file scope (shared by all suites). |
| B7 | `Discover.xcodeproj/project.pbxproj` | `namespaces_sample.xml` & `youtube_sample.xml` existed on disk but were **not bundled** into the test target → those tests threw `missingResource` at runtime. | Added both to the test target's Copy Bundle Resources. |
| B8 | `Core/Parsing/RSSParser.swift` | **Real parser bug:** media-namespace detection used `namespaceURI?.contains("media")`, but the standard Media RSS namespace is `http://search.yahoo.com/mrss/` (no "media" substring) → `media:content`, `media:thumbnail`, and YouTube `media:group` thumbnails were **never extracted** (`mediaUrl`/`mediaType`/`thumbnail` always nil). | Added `isMediaNamespace(_:_:)` matching the real `mrss` URI (+ `media:` qName fallback); also made first-value-wins for media:content/thumbnail. Fixed 3 failing parser tests. |
| B9 | `DiscoverTests/DiscoverTests.swift` | `defaultCategoryCount()` asserted `== 12` but `DefaultFeeds` has **13** categories (data grew: `general`, `business`, `adhd` added) → stale assertion. | Updated expectation (and test name) to 13. |

## Critical 🔴

### 1. String Index Invalidation Crash in `HTMLStripper.swift`
- **Location:** `macos-app/Discover/Core/Utilities/HTMLStripper.swift`
- **Description:** Mutating a string invalidates all existing `String.Index` objects. Accessing indices during the loop causes a deterministic runtime crash (*"Fatal error: String index is invalid"*).
- **Status:** FIXED natively by recalculating indices without Swift's string range invalidation.

## Major 🟠

### 2. Broken iOS Navigation in `ContentView.swift`
- **Location:** `macos-app/Discover/App/ContentView.swift`
- **Description:** iOS conditionally appends views instead of pushing onto a `NavigationStack`. The user will have no 'Back' button, breaking the core navigation flow.
- **Status:** FIXED natively by using `navigationDestination()`.

### 3. Missing `FeedModel` State Updates
- **Location:** `macos-app/Discover/Features/ArticleList/ArticleListViewModel.swift`
- **Description:** Failing to update `feed.lastFetchedAt` or `feed.lastError` in the database after a fetch.
- **Status:** FIXED natively in `ArticleListViewModel.swift`.

### 4. Unpersisted "Read" State on Article Open
- **Location:** `macos-app/Discover/Features/ArticleCard/ArticleCardView.swift`
- **Description:** Tapping an article fails to call `modelContext.save()`. Data loss occurs if the app closes.
- **Status:** FIXED natively by saving immediately.

### 5. Unimplemented App Preferences (New)
- **Location:** `macos-app/Discover/Features/Preferences/PreferencesView.swift` (and Views/ViewModels)
- **Description:** The app defines `@AppStorage` for Auto-refresh interval, Max Article Age, Mark as Read on Open, and Open Links in Background. NONE of these preferences are actually wired up. Auto-refresh is hardcoded to 15 minutes, old articles are never deleted, articles are always marked as read, and links always open in the foreground.
- **Status:** FIXED natively by wiring up `@AppStorage` in `ArticleListView.swift`, `ArticleListViewModel.swift`, and card views. The refresh loop is now reactive, and articles are purged correctly based on age settings.

## Minor 🟡

### 6. N+1 Query Performance Bottleneck in Upsert
- **Location:** `macos-app/Discover/Features/ArticleList/ArticleListViewModel.swift`
- **Description:** `upsert(_:into:)` loops over newly downloaded articles and performs a `context.fetch()` for every single item.
- **Status:** FIXED natively by pre-fetching IDs.

### 7. Orphaned Feeds on Category Deletion
- **Location:** `macos-app/Discover/Features/FeedManager/FeedManagerViewModel.swift`
- **Description:** Deleting a category does not re-assign feeds to the "general" category.
- **Status:** FIXED natively.

### 8. Fragile String Instantiation in `OGImageActor`
- **Location:** `macos-app/Discover/Core/Services/OGImageActor.swift`
- **Description:** Reading 50KB byte slice of an HTML stream can bisect UTF-8 characters, returning `nil` and skipping OG extraction.
- **Status:** FIXED natively.

### 9. Unbounded Memory Leak in `OGImageActor` Cache
- **Location:** `macos-app/Discover/Core/Services/OGImageActor.swift`
- **Description:** The `cache` dictionary stores `String?` values for every article URL indefinitely. Without eviction, this cache grows unbounded, leading to memory bloat over long sessions.
- **Status:** FIXED natively by limiting the cache size to 500 items and clearing it when full.

### 10. Silent Overwrites in `FeedManagerViewModel`
- **Location:** `macos-app/Discover/Features/FeedManager/FeedManagerViewModel.swift`
- **Description:** When adding a feed URL or a category slug that already existed, SwiftData's `upsert` behaviour blindly overwrote the existing models, resetting states like `lastFetchedAt`, `enabled`, and category colours.
- **Status:** FIXED natively by verifying uniqueness using a `FetchDescriptor` and showing a duplicate error message before insertion.
