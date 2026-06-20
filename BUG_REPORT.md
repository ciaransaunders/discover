# BUG REPORT — Discover Project

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
