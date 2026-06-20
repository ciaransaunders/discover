# Discover (macOS) — Phase 0 Feature Plan

**Status:** Draft for owner sign-off — no code to be written until approved.
**Scope:** Add NetNewsWire-style reading/organisation/platform features to the native `macos-app/` SwiftUI app.
**Date:** 2026-06-20

---

## 1. Overview

This plan adds NetNewsWire-class features to the Discover macOS app across seven feature clusters (A–G): an in-app **Reader** with customisable typography and explicit dark-mode control; **keyboard navigation** and single-key shortcuts; **organisation** (folders, starred, hide-read); **smart feeds** (All Unread, Today); a hardened **feeds engine** (add-by-URL with autodiscovery, app-lifetime background refresh, real search); **Mac platform** integration (customisable toolbar, multi-window, AppleScript); and a **Safari Web Extension** for one-click feed-adding. The guiding constraints are non-negotiable and inherited from `AGENTS.md`/`CLAUDE.md`: **zero third-party dependencies** (Foundation + SwiftUI + SwiftData only), **dark mode only**, **SF Symbols only**, **strict Swift 6 concurrency** (actors for async, `@MainActor` for UI/SwiftData), **idempotent seeding**, an **immutable djb2 article-ID scheme** (must byte-match the web app), and **additive-only schema changes** — nothing in the existing SwiftData store is dropped, renamed, or retyped. Every cluster reuses the existing fetch/parse/persist pipeline and shared UI components rather than rebuilding them.

---

## 2. Current architecture (as-is)

### Data model — 3 `@Model` types, fully denormalised (string-keyed, **zero `@Relationship`s**)

**`ArticleModel`** (`Core/Models/ArticleModel.swift`)
| Field | Type | Notes |
|---|---|---|
| `id` | String | `@Attribute(.unique)`; two-pass djb2 of `feedUrl + "::" + guid`; **immutable** (matches web app) |
| `title` | String | |
| `snippet` | String | truncated (~200 chars, sentence-aware) |
| `link` | String | |
| `source` | String | human-readable feed name |
| `category` | String | slug matching `CategoryModel.slug` |
| `thumbnail` | String? | best-available image URL |
| `publishedAt` | Date | |
| `isRead` | Bool | default `false` |
| `feedUrl` | String? | original feed URL for single-feed refresh |
| `fetchedAt` | Date | default `.now` |

**`CategoryModel`** (`Core/Models/CategoryModel.swift`): `slug` (`@Attribute(.unique)`), `label`, `colorHex`, `priority` (Int, default 0).
**`FeedModel`** (`Core/Models/FeedModel.swift`): `url` (`@Attribute(.unique)`), `name`, `category`, `useOgImage` (Bool, default false), `enabled` (Bool, default true), `lastFetchedAt` (Date?), `lastError` (String?).

No inverse relationships; `category`/`feedUrl` are denormalised string slugs. **No `VersionedSchema`/`SchemaMigrationPlan` exists** — schema is inferred from code; `DiscoverApp.makeModelContainer()` builds `Schema([ArticleModel, FeedModel, CategoryModel])` and falls back to in-memory storage if the on-disk store fails to open.

### Feed engine entry points (`Core/Services`, `Core/Parsing`)
- `RSSFetcherActor.shared.fetchAll(feeds:) -> [FeedFetchResult]` and `.fetchOne(feed:) -> FeedFetchResult` (concurrent, 15 s timeout, Sendable I/O; isolated from SwiftData/UI).
- `RSSParser.parse(...)` / `.parseWithDiagnostics(...)` → `[ParsedItem]` (+ error) via `XMLParser`; auto-detects RSS 2.0 / Atom 1.0; stamps feed metadata. `ParsedItem` carries a full `content` field (content:encoded / atom:content) that is currently **discarded at upsert**.
- `ThumbnailExtractor.extract()` (media:content → media:thumbnail → enclosure → first `<img>`); `OGImageActor.shared.ogImage(for:)` (streamed first ~50 KB, regex og:image, 500-entry LRU; only for feeds flagged `useOgImage`).
- Pure helpers: `IDGenerator` (djb2), `URLNormaliser`, `HTMLStripper`, `SnippetTruncator`, `ModelContext.saveOrLog(_:)`.
- The `@MainActor` `ArticleListViewModel` owns the dedup/`upsert`/`purgeOldArticles` write path and `refresh(context:)`.

### Feature / UI pattern
View + ViewModel pairs under `Features/<Feature>/`. Views hold transient state (`@State`, `@AppStorage`, `@Binding`, `@Environment(\.modelContext)`); `@Observable @MainActor` ViewModels hold business/refresh state; `@Query` provides live reads. `ArticleListView` builds a **dynamic category-filtered `@Query` predicate in its `init`** and post-filters `displayedArticles` in memory for search; hero = `displayedArticles[0]`, grid = the rest. Sidebar selection today is a bare `String?` category slug passed `ContentView → CategorySidebarView → ArticleListView`. Articles open **externally** (`NSWorkspace.shared.open`) — there is **no detail/reader view** and **no "selected article" concept** anywhere. Shared components: `GlassCard`/`.glassCard`, `CategoryBadge`, `FaviconImage`, `TimeAgoText`, `Color(hex:)`. Open/mark-read logic is **privately duplicated** across `ArticleCardView` and `HeroCardView`.

### App / scene + project / test setup
- `@main DiscoverApp`: single `WindowGroup { ContentView() }`, `.modelContainer(modelContainer)`, macOS `.windowStyle(.hiddenTitleBar)`, `.commands` (⌘R refresh, ⌘⇧R force-refresh, ⌘, preferences) via `NotificationCenter`. Min window 900×600.
- Targets: **Discover** (macOS app, bundle `com.discover.app`, deploy macOS 26.0, Swift 6.0, sandboxed, hardened runtime, `DEVELOPMENT_TEAM` empty). Entitlements (`Discover/Resources/Discover.entitlements`): `com.apple.security.app-sandbox` + `com.apple.security.network.client` only.
- **DiscoverTests** uses **Swift Testing** (not XCTest); fixtures in `DiscoverTests/Fixtures/` (`rss_sample.xml`, `atom_sample.xml` present; `namespaces_sample.xml`, `youtube_sample.xml` referenced but **missing → currently failing**). No iOS target yet (`DiscoverMobile` planned). No package dependencies.

---

## 3. Consolidated SwiftData schema changes — single source of truth

**Every** schema change below is **additive**. No existing property is dropped, renamed, or retyped; no `@Relationship` is introduced (the all-string denormalised design is preserved); the djb2 `id` scheme is untouched (so no read-state reset). Reconciliation across clusters is the point of this table: where multiple clusters touch the same model, there is **one** agreed delta here, not seven.

### New stored properties

| Model | New property | Type | Default | Additive? | Owning cluster(s) | Migration |
|---|---|---|---|---|---|---|
| `ArticleModel` | `content` | `String?` | `nil` | ✅ | A (Reader) | Lightweight (new optional) |
| `ArticleModel` | `isStarred` | `Bool` | `false` | ✅ | C (Starred) | Lightweight (defaulted) |
| `FeedModel` | `createdAt` | `Date?` | `nil` | ✅ | E (add-by-URL sort) | Lightweight (new optional) |

### New `@Model` types

| Type | Fields | Additive? | Owning cluster | Schema array change |
|---|---|---|---|---|
| `FolderModel` | `slug` (`@Attribute(.unique)`), `name`, `feedUrls: [String]`, `iconSystemName` (default `"folder.fill"`), `priority: Int` | ✅ | C (Folders) | **Append `FolderModel.self`** to `Schema([...])` in `DiscoverApp.makeModelContainer()` |

**Totals: 3 new stored properties, 1 new `@Model` type.**

### Overlap reconciliation (the coherence-critical part)
- **`ArticleModel` is touched by three clusters** (A `content?`, C `isStarred`). These are independent additive fields; they conflict only *textually* (same property block + same `init` signature + same `ArticleModel(...)` call site in `ArticleListViewModel.upsert`). **Convention:** every new property goes on its own line, appended to the **end** of the property list and `init` signature, with a one-line comment naming its cluster. Whoever merges second appends their argument rather than reordering.
- **"starred" lives only on `ArticleModel.isStarred`** (cluster C). Cluster D's "All Unread" smart feed and any `.starred` smart-feed row read this same field — they do **not** add their own boolean.
- **"isRead / hide read" is read-state only** — `ArticleModel.isRead` already exists. Hide-read (cluster C) is **preferences-only** (`@AppStorage`), **no schema change**; smart feeds (cluster D) are **query-only** over `isRead`/`publishedAt`, **no schema change**.
- **"folder" is one new model** (`FolderModel`, cluster C), feed-grouping via `feedUrls: [String]` joined on the existing unique `FeedModel.url`. No `ArticleModel.folder` field, no `@Relationship`. Folders are **orthogonal** to categories (a feed keeps its single category and may also sit in any folders).
- **`SidebarSelection`** (the navigation vocabulary used by C and D) is a **non-persisted `Sendable` enum**, *not* a `@Model` → **zero schema impact**. It is the single shared selection type both clusters extend (see §5).
- **Everything else is non-schema:** theme/appearance (A), view options/sort (F), keyboard state (B), refresh/search/recent-searches (E), window payload (F), and the Safari `PendingFeed` JSON inbox (G) all live in `@AppStorage` / `@State` / a JSON file in an App Group — **never** in SwiftData.

### Migration approach
All three property additions are lightweight-migratable (new optional, or non-optional with a default); the new `@Model` is additive. **Risk:** the project has **no `SchemaMigrationPlan`/`VersionedSchema`**, so this relies on SwiftData automatic lightweight migration. This is expected to succeed but **must be verified in Xcode against a populated on-disk store** (sandbox `xcodebuild` may fail on `@Model` macro expansion). See Open Question OQ-1.

---

## 4. Per-feature plans (by cluster)

> Files are absolute under `/Users/ciaran/Desktop/news-project/macos-app/`. "Reuses" lists existing components leaned on so nothing is rebuilt.

### Cluster A — Reading experience (Reader view, customisable themes, Dark Mode)

**A1. Reader view (in-app article reading)**
- **Approach:** New `Features/Reader` module. `ReaderView` presented as a `.sheet` on card tap (keeping an explicit "Open in Browser" affordance). `NavigationStack` + `ScrollView`: hero `AsyncImage`, `CategoryBadge`, title, `FaviconImage` + `TimeAgoText` source row, then body. Body source priority: `article.content` (new field) → `article.snippet` → empty state. RSS HTML rendered as readable text via `HTMLStripper` paragraph mode — **no WKWebView** (honours dark-only + no-dep). Toolbar: Done / Open in Browser / `ShareLink` / Mark Read. Marks read on open per existing `@AppStorage`.
- **Edit:** `Features/ArticleCard/ArticleCardView.swift`, `Features/ArticleCard/HeroCardView.swift`, `Core/Models/ArticleModel.swift`, `Features/ArticleList/ArticleListViewModel.swift` (persist `item.content` at upsert), `Core/Utilities/HTMLStripper.swift`.
- **Create:** `Features/Reader/ReaderView.swift`, `Features/Reader/ReaderViewModel.swift`, `Core/Utilities/ArticleOpener.swift` (consolidates duplicated open/copy logic).
- **Schema:** `ArticleModel.content: String?` (additive; see §3).
- **Reuses:** `GlassCard`, `CategoryBadge`, `FaviconImage`, `TimeAgoText`, `Color(hex:)`, `saveOrLog`, existing card `AsyncImage` pattern, `@AppStorage` read flags.
- **Tests:** body-source priority; HTMLStripper paragraph mode (entities, no index crash); upsert persists `content`; `ArticleOpener` background-open config.
- **Risks:** RSS content quality varies (mitigated by snippet fallback + "Read full article"); behaviour change — tap now opens reader (mitigate with reversible `@AppStorage("tapOpensReader")`); store-size growth (bounded by existing purge).

**A2. Customisable article themes**
- **Approach:** `ReaderThemeManager` (`@Observable @MainActor`, Sendable value types: `fontScale`, `fontFamily` enum system/serif/mono, `lineWidth` enum), hydrated via `@AppStorage`-compatible primitives, injected once from `DiscoverApp` via `.environment`. New PreferencesView "Appearance" section with live mini-preview. **Category colours stay on `CategoryModel`** (not overridden) — theme governs typography/layout only.
- **Edit:** `App/DiscoverApp.swift`, `Features/Preferences/PreferencesView.swift`, `Features/Reader/ReaderView.swift`.
- **Create:** `UI/Theme/ReaderThemeManager.swift`, `UI/Theme/ReaderFontFamily.swift`.
- **Schema:** none (UserDefaults).
- **Reuses:** `@AppStorage` pattern, PreferencesView Form/Section, `Color(hex:)`.
- **Tests:** sane defaults; persistence round-trip in a test suite; `fontScale` clamp; font-family ↔ `Font.Design`.
- **Risks:** double-sourcing the same `@AppStorage` key — manager is the single owner, PreferencesView binds to the manager. Namespace keys (`reader.fontScale`).

**A3. Dark Mode (explicit appearance control, dark-only honoured)**
- **Approach:** App currently sets no `colorScheme` → washes out on a light-mode Mac. Add `AppAppearance` enum (system/dark; **`light` deliberately omitted**) to `ReaderThemeManager`; apply `.preferredColorScheme(resolvedColorScheme)` (resolves both cases → `.dark` for now) at the **WindowGroup content root** so all sheets inherit it. Plumbing makes a future Light mode purely additive.
- **Edit:** `App/DiscoverApp.swift`, `Features/Preferences/PreferencesView.swift`, `UI/Theme/ReaderThemeManager.swift`.
- **Create:** `UI/Theme/AppAppearance.swift`.
- **Schema:** none.
- **Reuses:** `ReaderThemeManager`, WindowGroup scene, Appearance section.
- **Tests:** resolver maps system/dark → `.dark`; no `light` case; persistence round-trip.
- **Risks:** modifier must sit on the WindowGroup root so detached sheets inherit dark; do not regress `.hiddenTitleBar`/`.commands` chain.

---

### Cluster B — Navigation / input (keyboard navigation + single-key shortcuts)

**Zero schema changes.** Introduces the "selected article" concept the app lacks.

**B1. Keyboard navigation (move between feeds/articles)**
- **Approach:** `NavigationStateModel` (`@Observable @MainActor`, `selectedArticleID: String?` keyed on the stable djb2 id) owned by `ContentView`, injected via `.environment`. Selection order = the existing `displayedArticles` (single source of truth). Article scroll region gets `.focusable` + `@FocusState` + `ScrollViewReader` (`scrollTo(article.id)`). Cards gain a **defaulted** `isSelected: Bool` param drawing a category-accent ring over `.glassCard`. Tab / `[` / `]` cycle the existing `selectedCategory`. All `#if os(macOS)`.
- **Edit:** `App/ContentView.swift`, `Features/ArticleList/ArticleListView.swift`, `Features/ArticleCard/ArticleCardView.swift`, `Features/ArticleCard/HeroCardView.swift`.
- **Create:** `Features/Navigation/NavigationStateModel.swift`.
- **Reuses:** `ArticleModel.id`, `displayedArticles`, `selectedCategory` binding, `.glassCard`, `Color(hex:)`.
- **Tests:** pure index math (next/previous/clamp, absent-id resets to nil, category cycle incl. nil "All").
- **Risks:** focus stolen by `.searchable` (gate on `listFocused && !searchFieldFocused`); selection points at purged article (resolve by id each render, fall back to nil); keep `isSelected` defaulted so call sites compile; `.id(article.id)` on cards for `scrollTo`.

**B2. Single-key shortcuts (NetNewsWire-style)**
- **Approach:** One `.onKeyPress` router on the focusable list region: `n`/`j` next, `p`/`k` previous, space/return open, `r` toggle read, `m` mark read, `u` unread, Tab/`[`/`]` category, Esc clear. **Not** registered as menu `.keyboardShortcut` (would capture single letters globally). Extract the duplicated open/mark-read logic into `ArticleActions` (Core helper) so keyboard and click share one code path. Help menu `CommandGroup` + PreferencesView entries are **documentation only**.
- **Edit:** `Features/ArticleList/ArticleListView.swift`, `Features/ArticleCard/ArticleCardView.swift`, `Features/ArticleCard/HeroCardView.swift`, `App/DiscoverApp.swift`, `Features/Preferences/PreferencesView.swift`.
- **Create:** `Core/Utilities/ArticleActions.swift`, `Features/ArticleList/ArticleKeyCommands.swift`.
- **Reuses:** existing open/mark-read logic (lifted into `ArticleActions`), `saveOrLog`, `Logger.ui`, `NavigationStateModel`, NSWorkspace background-open path.
- **Tests:** pure `(key,modifiers) → Command` mapper (incl. `.command` modifier → `.unhandled`); `ArticleActions` flips/persists `isRead` against an in-memory container.
- **Risks:** return/space vs default button activation (make the region the focus target, return `.ignored` for unowned keys); keep extracted bodies byte-identical; the **`ArticleActions.open` seam** is the single place to later switch space/return from browser to Reader.

---

### Cluster C — Organisation (Folders, Starred, Hide read)

**C1. Starred articles**
- **Approach:** `ArticleModel.isStarred: Bool = false`. Star toggle in both card `.contextMenu`s (`star`/`star.fill`) + header badge. "Starred" sidebar row (`SidebarSelection.starred`). `ArticleListView` `@Query` init gains a `.starred` predicate (`#Predicate { $0.isStarred }`).
- **Edit:** `Core/Models/ArticleModel.swift`, `Features/ArticleCard/ArticleCardView.swift`, `Features/ArticleCard/HeroCardView.swift`, `Features/CategorySidebar/CategorySidebarView.swift`, `Features/ArticleList/ArticleListView.swift`.
- **Schema:** `ArticleModel.isStarred` (additive; see §3).
- **Reuses:** `@Bindable` card binding, `.contextMenu`, `saveOrLog`, `CategoryBadge` slot, live `@Query`.
- **Tests:** default false; toggle persists; starred predicate returns only starred; composes with category.
- **Risks:** no-migration-plan store (mitigated by default; verify in Xcode); card header overflow on narrow cards.

**C2. Hide read articles / hide read feeds** — *pure view-layer, no schema*
- **Approach:** `@AppStorage("hideReadArticles")` + `@AppStorage("hideReadFeeds")`. Extend `displayedArticles` to drop read items after search; toolbar quick toggle (`eye.slash`). "Read feed" = zero unread (computed via one grouped unread fetch + Set lookup, not per-feed queries).
- **Edit:** `Features/Preferences/PreferencesView.swift`, `Features/ArticleList/ArticleListView.swift`, `Features/CategorySidebar/CategorySidebarView.swift`, `Features/FeedManager/FeedManagerView.swift`.
- **Reuses:** `@AppStorage` pattern, in-memory filter chain, existing empty-state, `markAllRead()`, live `@Query`.
- **Tests:** extract pure `ArticleFilter.visible(...)` helper — drops read when on, keeps all when off, composes with search, empty when all-read; `feedHasUnread`.
- **Risks:** hero on empty list (guard via existing `if displayedArticles.isEmpty`); keep unread-count computation cheap (grouped fetch).

**C3. Folders (group feeds)**
- **Approach:** New `FolderModel` (string-join, **no `@Relationship`**, `feedUrls: [String]`). New "Folders" tab in FeedManager (CRUD via `FeedManagerViewModel`, uniqueness checks mirroring `addCategory`). Sidebar "Folders" section; selecting sets `SidebarSelection.folder(slug, feedUrls)`. Because `ArticleListView`'s `@Query` is built in `init` with no `modelContext`, the folder's resolved `feedUrls` are **carried in the selection** and used to build `#Predicate { folderFeedUrls.contains($0.feedUrl ?? "") }`.
- **Edit:** `App/DiscoverApp.swift` (Schema array), `Features/FeedManager/FeedManagerView.swift`, `Features/FeedManager/FeedManagerViewModel.swift`, `Features/CategorySidebar/CategorySidebarView.swift`, `App/ContentView.swift`, `Features/ArticleList/ArticleListView.swift`.
- **Create:** `Core/Models/FolderModel.swift`, `Core/Models/SidebarSelection.swift`.
- **Schema:** new `FolderModel` + Schema-array append (additive; see §3).
- **Reuses:** `FeedModel.url` unique key, FeedManager tabbed UI, VM uniqueness/priority patterns, sidebar Section builders, `saveOrLog`, live `@Query`.
- **Tests:** folder created empty; add/remove feed no-dupes; slug uniqueness; dangling feed URL matches zero articles; **`SidebarSelection` rawValue round-trip for all cases** (critical for the iOS String binding).
- **Risks:** forgetting the Schema-array edit; `#Predicate` `Array.contains` + optional-coalescing support (fallback: in-memory filter — see OQ-2); keep folders orthogonal to categories.

---

### Cluster D — Smart feeds (All Unread, Today)

**No schema change** — reuses `isRead` and `publishedAt`. Both features hang off **`SidebarSelection`**, widening sidebar selection from `String?` to the enum (`.all`, `.allUnread`, `.today`, `.category(String)`).

**D1. "All Unread"**
- **Approach:** New "Smart Feeds" sidebar Section row with live unread count badge (store-wide `@Query` count). `ArticleListView.init` accepts `SidebarSelection`; `.allUnread` builds `#Predicate { !$0.isRead }`, sorted publishedAt-desc. Everything downstream reused verbatim; refresh maps to existing whole-store `refresh(context:)`.
- **Edit:** `App/ContentView.swift`, `Features/CategorySidebar/CategorySidebarView.swift`, `Features/ArticleList/ArticleListView.swift`.
- **Create:** `Core/Models/SidebarSelection.swift` *(shared with cluster C — author once)*.
- **Tests:** unread predicate returns only unread, desc-sorted; drops after mark-read; nav-title mapping; count badge math.
- **Risks:** view must re-`init` on enum change (add `.id(selection)` on the detail column if needed); keep iOS TabView paths working.

**D2. "Today"**
- **Approach:** `.today` row; `ArticleListView.init` captures `let startOfToday = Calendar.current.startOfDay(for: .now)` into `#Predicate { $0.publishedAt >= startOfToday }` (proven captured-Date pattern, same as `purgeOldArticles`). Predicate built via a factory taking `now: Date = .now` for deterministic tests.
- **Edit:** `App/ContentView.swift`, `Features/CategorySidebar/CategorySidebarView.swift`, `Features/ArticleList/ArticleListView.swift`.
- **Tests:** only today's rows, inclusive of startOfDay boundary, future-dated included; deterministic injected `now`.
- **Risks:** cross-midnight staleness until view re-inits (acceptable v1; OQ); never call `Date.now`/`Calendar` inside the macro body.

---

### Cluster E — Feeds engine (Add-by-URL + autodiscovery, Background refresh, Search)

**E1. Direct feed downloading (add by URL with autodiscovery)**
- **Approach:** New `FeedDiscoveryActor` (Swift `actor`, Sendable I/O, no SwiftData). `discover(from:)`: normalise → try `RSSFetcherActor.fetchOne`; if zero items, fetch page HTML (capped ~100 KB, OGImageActor-style stream) and scan `<link rel="alternate" type="application/(rss|atom)+xml">`, resolve relative hrefs, retry. `FeedManagerViewModel.discoverAndAddFeed` validates-then-adds, infers name from feed `<title>`, then upserts prefetched items. **Extract the private `upsert` from `ArticleListViewModel` into `ArticleUpsertService`** so both VMs share it.
- **Edit:** `Features/FeedManager/FeedManagerViewModel.swift`, `Features/FeedManager/FeedManagerView.swift`, `Features/ArticleList/ArticleListViewModel.swift`, `Core/Parsing/RSSParser.swift` (additively surface the already-tracked `feedTitle`).
- **Create:** `Core/Services/FeedDiscoveryActor.swift`, `Core/Services/ArticleUpsertService.swift`.
- **Schema:** none directly (`FeedModel.createdAt` declared under E's consolidated delta, §3).
- **Reuses:** `RSSFetcherActor.fetchOne`/`FeedDescriptor`, `RSSParser`, `URLNormaliser`, `IDGenerator`/`SnippetTruncator`/`HTMLStripper`, existing uniqueness + ensure-category, OGImageActor stream pattern.
- **Tests:** `extractFeedLinks(fromHTML:baseURL:)` (rss/atom, relative hrefs, none); feed-title from fixture; `ArticleUpsertService` dedup against in-memory container; new fixture `html_with_feed_link.html`.
- **Risks:** no injectable URLSession (isolate pure parsing seams); brittle HTML regex (accept first valid, clear error otherwise); extracting `upsert` touches a hot recently-fixed path — preserve behaviour byte-for-byte; UA spoofing reused from OGImageActor.

**E2. Background refreshing (app-lifetime scheduler)**
- **Approach:** Replace the view-scoped `.task(id: refreshInterval)` loop with `RefreshScheduler` (`@MainActor @Observable`) owning one long-lived Task started from `ContentView`'s top-level `.task`. Reads `@AppStorage("refreshIntervalMinutes")`, offline-guard, writes `lastBackgroundRefresh`. macOS-only opt-in `notifyOnNewArticles` posts a `UNUserNotification` of new-article counts (gated; ships off by default).
- **Edit:** `App/ContentView.swift`, `Features/ArticleList/ArticleListView.swift`, `Features/ArticleList/ArticleListViewModel.swift`, `Features/Preferences/PreferencesView.swift`, `App/DiscoverApp.swift`.
- **Create:** `Features/Refresh/RefreshScheduler.swift`, `Core/Services/NewArticleNotifier.swift`.
- **Schema:** none (`@AppStorage`).
- **Reuses:** existing refresh pipeline + `purgeOldArticles`, NotificationCenter plumbing, `TimeAgoText`, offline-error mapping.
- **Tests:** pure `nextFireDelay(...)` / `shouldRefresh(...)` boundaries (0 = never, >0 = interval×60, offline = skip); `notificationBody(forNewCount:)` pluralisation + nil-when-zero.
- **Risks:** must replicate `.task(id:)` restart semantics + not double-fire on launch; **notification entitlement unconfirmed (OQ)** — ship scheduler first, gate notifications.

**E3. Searching**
- **Approach:** Push search into a debounced SwiftData `#Predicate` (`localizedStandardContains` over title/snippet/source, AND category), via a `committedSearch` updated by a `.task(id: searchText)` ~250 ms debounce. `.searchScopes` (All / Unread / This Category) + recent searches in `@AppStorage` JSON + `.searchSuggestions`. Feed search added to FeedManager (in-memory).
- **Edit:** `Features/ArticleList/ArticleListView.swift`, `Features/FeedManager/FeedManagerView.swift`, `Features/Preferences/PreferencesView.swift`.
- **Create:** `Features/ArticleList/ArticleSearchScope.swift`.
- **Schema:** none.
- **Reuses:** existing `.searchable` slot, `displayedArticles`, dynamic-predicate init, empty-state, FeedManager `@Query`.
- **Tests:** pure `ArticleSearchMatcher.matches(...)` (case-insensitive title/snippet/source, Unread/This-Category scopes, empty term = all); `FeedSearchMatcher`.
- **Risks:** combined `#Predicate` may not compile under the macro → fallback to category-only `@Query` + debounced in-memory matcher; debounce mandatory; guard recent-search JSON decode.

---

### Cluster F — Mac platform (Customisable toolbar, Multi-window, AppleScript)

**Schema-neutral entirely.**

**F1. Customisable toolbar**
- **Approach:** Move the inline `.toolbar` to `.toolbar(id:)` + identified `ToolbarItem(id:placement:showsByDefault:)` (Refresh / Force / Mark All Read / Feeds + new View-density and Sort menus), enabling system "Customize Toolbar…". New view options (`columnCount`, `sortOrder`, `density`) in `@AppStorage`; sort applied as an in-memory re-sort over `displayedArticles`.
- **Edit:** `Features/ArticleList/ArticleListView.swift`, `Features/Preferences/PreferencesView.swift`.
- **Create:** `Features/ArticleList/ArticleListToolbar.swift`, `Core/Models/ArticleSortOrder.swift`.
- **Reuses:** existing toolbar actions, `TimeAgoText`, adaptive `columns`, `@AppStorage`.
- **Tests:** `ArticleSortOrder` raw-value stability + comparator (date-desc/asc, source-AZ); hero matches chosen sort.
- **Risks:** **customisable toolbar vs `.hiddenTitleBar`** (OQ — may need `.titleBar`); unique/stable item ids; only certain placements are customisable.

**F2. Multiple-window support**
- **Approach:** `WindowGroup(for: DiscoverWindowSelection.self)` (macOS branch; iOS keeps plain `WindowGroup`). New `Sendable`/`Codable`/`Hashable` `DiscoverWindowSelection { category: String? }`. `CommandGroup(replacing: .newItem)` → ⌘N via `openWindow`. `ContentView` gains an optional `launchSelection` seeding its `@State` (per-window independence). Single injected `ModelContainer` shared across windows → live `@Query` everywhere.
- **Edit:** `App/DiscoverApp.swift`, `App/ContentView.swift`, `Features/CategorySidebar/CategorySidebarView.swift`.
- **Create:** `App/DiscoverWindowSelection.swift`.
- **Reuses:** single `.modelContainer`, NavigationSplitView, sidebar binding, `.commands`, `@Environment(\.openWindow)`.
- **Tests:** Codable round-trip; Hashable/Equatable nil vs non-nil; restored-but-deleted category falls back to nil.
- **Risks:** re-apply `.hiddenTitleBar`/`.frame` per scene; stale restored category; **if a Folders/Smart-feeds richer selection lands first, replace `DiscoverWindowSelection.category` with that type** (see §5).

**F3. AppleScript support**
- **Approach:** `Discover.sdef` + `Info.plist` `OSAScriptingDefinition`; `@NSApplicationDelegateAdaptor`; thin bridge — action commands (`refresh feeds`, `force refresh feeds`) post existing notifications; read-only `unread count`/`article count` via a `@MainActor ScriptingDataReader` running `FetchDescriptor` counts. Modern `NSScriptCommand` subclass approach (Swift 6 safe). No scriptable object model in v1.
- **Edit:** `App/DiscoverApp.swift`, `Discover/Resources/Info.plist`.
- **Create:** `Discover/Resources/Discover.sdef`, `App/AppDelegate.swift`, `App/Scripting/RefreshFeedsCommand.swift`, `App/Scripting/ScriptingDataReader.swift`.
- **Reuses:** existing `.refreshFeeds`/`.forceRefreshFeeds` notifications + observers, shared `ModelContainer` (read-only), `Logger.ui`.
- **Tests:** `ScriptingDataReader` counts against in-memory container, asserts no writes; `Discover.sdef` parses + validates against `sdef.dtd`.
- **Risks:** unique 4-char codes; `@NSApplicationDelegateAdaptor` lifecycle minimalism; `MainActor.assumeIsolated` for ModelContainer access in `performDefaultImplementation`; **Info.plist + `.pbxproj` edit requires Xcode closed** (project gotcha); scripting **other** apps would need `apple-events` entitlement (not in v1).

---

### Cluster G — Safari extension (one-click feed-adding)

**Schema-neutral.** Cross-process design: extension → App Group JSON inbox → app drains into SwiftData via the existing idempotent feed-add contract.

**G1. Safari Web Extension target + RSS-discovery popup**
- **Approach:** New embedded macOS Safari Web Extension (created via **Xcode UI**, not hand-edited `.pbxproj`). Vanilla JS content script discovers `<link rel="alternate" type=".../rss|atom+xml">` (+ common-path fallback); dark Liquid-Glass popup lists feeds; "Add to Discover" calls `sendNativeMessage`. `SafariWebExtensionHandler` (the only Swift in the target) appends a `PendingFeed` to the inbox — **no SwiftData in the extension**. manifest v3; `activeTab` preferred over `<all_urls>` (OQ).
- **Edit:** `macos-app/Discover.xcodeproj/project.pbxproj` *(via Xcode UI)*, `Discover/Resources/Discover.entitlements`, `macos-app/CLAUDE.md`.
- **Create:** `DiscoverSafariExtension/` (`SafariWebExtensionHandler.swift`, `Info.plist`, `.entitlements`, `Resources/manifest.json`, `popup.{html,css,js}`, `content.js`, `background.js`, `images/toolbar-icon.svg`).
- **Schema:** none.
- **Reuses:** App Group container, `PendingFeedInbox`, app visual language (replicated in CSS).
- **Tests:** Node JS unit test of the discovery parser (`feed-discovery.test.js`); native side covered via G2/G3.
- **Risks:** extension must be manually enabled per machine; `<all_urls>` privacy/review friction; small nativeMessaging payloads; `.pbxproj` corruption if hand-written; needs rasterised PNG icon set.

**G2. App Group container + `PendingFeedInbox` bridge**
- **Approach:** One App Group id (proposed `group.com.discover.app`) shared by both targets — the only sanctioned cross-sandbox channel. `PendingFeedInbox` (Foundation only) does append/readAll/clear against `pending-feeds.json` with `NSFileCoordinator` atomic replace. `PendingFeed` is `Codable`/`Sendable`/`Hashable`. `AppGroup.swift` centralises the id; all three files are members of **both** targets (Foundation-only → compiles in the extension).
- **Edit:** `Discover.xcodeproj/project.pbxproj` *(Xcode UI)*, `Discover/Resources/Discover.entitlements`.
- **Create:** `Core/Utilities/AppGroup.swift`, `Core/Models/PendingFeed.swift`, `Core/Services/PendingFeedInbox.swift`.
- **Schema:** none (JSON file, not a `@Model`).
- **Reuses:** Foundation only; Sendable conventions.
- **Tests:** `PendingFeedInbox(containerURL:)` temp-dir injectable — append/readAll order, clear(consumed:), concurrent-append integrity, Codable round-trip.
- **Risks:** App Group entitlement is load-bearing (OQ) — degrade gracefully to `[]`/no-op if `containerURL` is nil; coordinate writes (atomic replace); id must match exactly in both entitlements + `AppGroup.swift`.

**G3. `SharedFeedImporter` — drain inbox into SwiftData**
- **Approach:** `@MainActor SharedFeedImporter.drain(context:)` reads the inbox and, per record, reuses the proven add-feed contract (skip if `FeedModel.url` exists, ensure category defaulting to "general", insert, save). Optional native validation via `RSSFetcherActor.fetchOne`. Clears consumed records. Wired into `DiscoverApp` via `.task`/`.onChange(of: scenePhase)` on launch + activate. Idempotent by unique URL.
- **Edit:** `App/DiscoverApp.swift`.
- **Create:** `Core/Services/SharedFeedImporter.swift`.
- **Schema:** none (inserts ordinary `FeedModel`/`CategoryModel` rows).
- **Reuses:** `FeedModel(...)` init, FeedManager uniqueness + ensure-category (lift into one shared helper), `RSSFetcherActor.fetchOne`, `saveOrLog`, `PendingFeedInbox`, live `@Query` (feed appears automatically).
- **Tests:** in-memory container + temp inbox — new inserted, duplicate skipped, "general" auto-created, inbox cleared, malformed URL rejected when validation on.
- **Risks:** keep validation off the critical path (async/non-blocking); `@MainActor` drain + actor await hop under Swift 6; `isDraining` guard against launch+activate double-fire; lift ensure-category into one helper to avoid drift.

---

## 5. Phase 1 execution & merge plan

### The coupling hotspots
1. **`ArticleModel.swift` + `ArticleListViewModel.upsert` call site** — touched by A (`content?`) and C (`isStarred`). Additive but textually collide.
2. **`SidebarSelection`** — invented by **both C and D**. This is the biggest risk: two clusters inventing a parallel selection type. **It must be authored once.**
3. **`ArticleListView.swift`** — the busiest shared file: `@Query` init/predicate (C, D, E), `displayedArticles` filter (C, E), toolbar (B, F), search (E), focus/selection (B). Everything funnels through `displayedArticles` as the single source of order/filter.
4. **`DiscoverApp.swift` / `ContentView.swift`** — scene-level edits from A (environment), B (nav state), C/D (selection), E (scheduler `.task`), F (multi-window + commands + adaptor), G (drain `.task`).
5. **`.pbxproj`** — only G adds targets/file memberships; must be done in Xcode UI with the project closed.

### Worktree grouping — what can run truly in parallel

| Group | Clusters | Parallel-safe? | Why |
|---|---|---|---|
| **Foundation** | **C + D together** (one worktree) | Must be **serialised into a single stream** | Both own `SidebarSelection` and both edit `ArticleListView.init`. Author the enum once with all cases (`.all/.allUnread/.today/.category/.folder/.starred`) and one predicate factory. |
| **Engine** | **E** | Parallel to UI clusters, but lands early | Extracts `ArticleUpsertService` + `RefreshScheduler` that others build on; only schema touch is the additive `FeedModel.createdAt`. |
| **Reading** | **A** | Parallel | Only model touch is `ArticleModel.content?`; rest is new files + `ReaderThemeManager`. |
| **Input** | **B** | Parallel, but rebase last among list-touchers | No schema; wraps `displayedArticles` via `orderedArticles`; its `ArticleActions.open` seam later points at the Reader. |
| **Platform** | **F** | Parallel for toolbar/AppleScript; multi-window rebases on the selection type | No schema; `DiscoverWindowSelection.category` may be replaced by the C/D selection type. |
| **Extension** | **G** | Parallel for source files; integration last | No schema; `.pbxproj`/App Group/entitlements done in Xcode UI at the very end. |

**Truly parallel:** A, E, and the C+D foundation stream can develop concurrently in separate worktrees because their schema deltas are independent additive lines. **Must be serialised:** C and D (shared `SidebarSelection` + `ArticleListView.init`) — treat as one stream, not two worktrees. B and F's multi-window must **rebase onto** the finalised selection type rather than racing it.

### Recommended merge order (rebuild + run tests after each merge)

1. **E (engine)** — lands `ArticleUpsertService`, `RefreshScheduler`, `FeedModel.createdAt`. Establishes the shared upsert/refresh seams everyone reuses. *Rebuild + test.*
2. **C + D (foundation, single stream)** — `SidebarSelection` (full case set + predicate factory), `FolderModel` + Schema-array append, `ArticleModel.isStarred`, smart-feed/folder/starred sidebar. Settles the selection vocabulary and the second `ArticleModel`/Schema edit. *Rebuild + test (verify migration against a populated store here — first schema-bearing landing after E).* 
3. **A (reading)** — rebase `ArticleModel.content?` and the `upsert` content-write on top of C/D's already-merged `ArticleModel`/Schema edits; land `ReaderThemeManager`/`ArticleOpener`. *Rebuild + test.*
4. **B (input)** — rebase so `orderedArticles = displayedArticles` inherits C/D/E filtering; if A is in, point `ArticleActions.open` at the Reader (one-line). *Rebuild + test.*
5. **F (platform)** — toolbar refactor first (so others add identified items, not inline), then multi-window rebased onto the C/D selection type, then AppleScript (`.pbxproj`/Info.plist with Xcode closed). *Rebuild + test.*
6. **G (extension)** — last; Foundation-only source files merge cleanly, then the Xcode-UI target creation + App Group + entitlements + `.pbxproj` as a discrete final integration step. *Rebuild + test.*

**Rebuild-after-each-merge note:** after every merge, do a clean build **in Xcode** (not just sandbox `xcodebuild`, which can fail on `@Model`/`@Query`/`@Observable` macro expansion) and run `Cmd+U` twice (see §8). The two schema-bearing merges (step 2, then step 3 rebasing onto it) are the migration checkpoints — confirm an existing on-disk store opens without reset before proceeding.

---

## 6. New tests (consolidated)

All Swift Testing (not XCTest); SwiftData tests use an in-memory `ModelContainer` over the **full** schema (incl. `FolderModel.self`).

- `DiscoverTests/ReaderBodyResolverTests.swift` — body source priority (content → snippet → empty).
- `DiscoverTests/HTMLStripperParagraphTests.swift` — paragraph strip, entity decode, no index crash.
- `DiscoverTests/UpsertContentPersistenceTests.swift` — upsert writes `ParsedItem.content` → `ArticleModel.content`.
- `DiscoverTests/ReaderThemeManagerTests.swift` — defaults, persistence round-trip, `fontScale` clamp.
- `DiscoverTests/ReaderFontFamilyTests.swift` — rawValue ↔ enum, `Font.Design` mapping.
- `DiscoverTests/AppAppearanceTests.swift` — resolver (system/dark → `.dark`), no `light` case, round-trip.
- `DiscoverTests/ArticleOpenerTests.swift` — background-open config via injectable seam.
- `DiscoverTests/Navigation/ArticleKeyCommandsTests.swift` — key/modifier → command mapping (incl. `.command` → unhandled).
- `DiscoverTests/Navigation/NavigationStateModelTests.swift` — index stepping/clamp, absent-id reset, category cycle incl. nil "All".
- `DiscoverTests/Navigation/ArticleActionsTests.swift` — toggleRead persists; open respects `markReadOnOpen` (injected flag).
- `DiscoverTests` `@Suite("Discover — Starred Articles")` — default unstarred, toggle persists, starred predicate.
- `DiscoverTests` `@Suite("Discover — Folders")` — empty folder, add/remove no-dupes, slug uniqueness, dangling-feed → zero articles.
- `DiscoverTests` `@Suite("Discover — SidebarSelection round-trip")` — all cases survive rawValue ↔ init (incl. `.folder` payload).
- `DiscoverTests` `@Suite("Discover — Hide Read Filtering")` — `ArticleFilter` drop/keep/compose/empty; `feedHasUnread`.
- `DiscoverTests/SmartFeedTests.swift` — unread predicate (+ drop after mark-read), today predicate (boundary-inclusive, deterministic `now`), nav-title mapping, count badge.
- `DiscoverTests/FeedDiscoveryTests.swift` — `extractFeedLinks(fromHTML:baseURL:)` (rss/atom/relative/none), feed-title from fixture.
- `DiscoverTests/ArticleUpsertServiceTests.swift` — no-duplicate on double upsert, ID match, `insertedCount`.
- `DiscoverTests/RefreshSchedulerTests.swift` — `nextFireDelay`/`shouldRefresh` boundaries.
- `DiscoverTests/NewArticleNotifierTests.swift` — `notificationBody(forNewCount:)` pluralisation + nil-when-zero.
- `DiscoverTests/ArticleSearchTests.swift` — `ArticleSearchMatcher` (case-insensitive, scopes, empty=all).
- `DiscoverTests/FeedSearchTests.swift` — `FeedSearchMatcher` over name/url/category.
- `DiscoverTests/ArticleSortOrderTests.swift` — raw-value stability, comparator correctness, hero matches sort.
- `DiscoverTests/WindowSelectionTests.swift` — Codable round-trip, Hashable, deleted-category fallback.
- `DiscoverTests/ScriptingDataReaderTests.swift` — counts correct, no writes.
- `DiscoverTests/SdefValidationTests.swift` — `Discover.sdef` well-formed + validates against `sdef.dtd`.
- `DiscoverTests/PendingFeedInboxTests.swift` — append/readAll/clear, concurrent-append integrity, Codable round-trip (temp-dir injected).
- `DiscoverTests/SharedFeedImporterTests.swift` — new inserted, duplicate skipped, "general" auto-created, inbox cleared, malformed rejected.
- `DiscoverTests/Fixtures/html_with_feed_link.html` — **new fixture** (add to test target's Copy Bundle Resources).
- `DiscoverSafariExtension/.../feed-discovery.test.js` — Node JS unit test of the content-script parser.
- *(Backlog, pre-existing)* add the missing `namespaces_sample.xml` and `youtube_sample.xml` fixtures that currently fail (noted in the architecture map).

---

## 7. Open questions for owner sign-off

**Schema / migration**
- **OQ-1 (non-additive risk — the one true schema risk):** No `SchemaMigrationPlan`/`VersionedSchema` exists. The 3 additive properties + 1 new `@Model` should migrate automatically (lightweight), but this is **unverified against a populated on-disk store**. Approve relying on automatic lightweight migration (vs authoring an explicit migration plan), and confirm acceptance that this must be validated in Xcode (not sandbox `xcodebuild`) before release. *Everything else in §3 is strictly additive — nothing is dropped/renamed/retyped.*
- **OQ-2:** `#Predicate { folderFeedUrls.contains($0.feedUrl ?? "") }` (Array.contains + optional-coalescing) — acceptable to fall back to in-memory folder filtering if the macro rejects it? (Implementation choice, flagged for awareness.)

**Safari extension — signing / entitlements / app-group**
- **OQ-3:** App Group entitlement (proposed `group.com.discover.app`) added to **both** app and extension requires a registered identifier and a set `DEVELOPMENT_TEAM`. Confirm the App Group id and that a team/provisioning profile is available.
- **OQ-4:** Adding the Safari Web Extension target re-signs the bundle and **requires re-notarisation** before distribution; needs its own bundle id (`com.discover.app.SafariExtension`) + entitlements. Approve the signing/notarisation impact.
- **OQ-5:** Extension permission scope — `activeTab` (on-demand, App-Store-friendly, default plan) vs `<all_urls>` (auto-discovery on any page, more privacy surface)?
- **OQ-6:** Safari-added feeds default to category "general" (extension can't read the user's category list cross-process). Acceptable, or ship a static picker (risks drift from `DefaultFeeds.categories`)?
- **OQ-7:** Extension icon — sanctioned exception to the SF-Symbols-only rule (Safari needs rasterised 16/32/48/128 PNGs derived from `assets/discover_app_icon.png`)?

**Other entitlement / platform**
- **OQ-8:** Local "N new articles" notifications (E2) — wanted at all? Confirm whether `UserNotifications` + `UNUserNotificationCenter` authorization needs a sandbox entitlement / Info.plist usage string under the current config; if so this is an entitlements change needing sign-off. Default: ship scheduler, gate notifications off.
- **OQ-9:** Customisable toolbar (F1) vs `.windowStyle(.hiddenTitleBar)` — may windows that expose a customisable toolbar switch to `.windowStyle(.titleBar)` (changes the Liquid-Glass top edge)? Otherwise "customisable" degrades to fixed.
- **OQ-10:** AppleScript command surface (F3) — confirm minimal v1 set (`refresh feeds`, `force refresh feeds`, read-only `unread count`/`article count`). Any mutating verb (e.g. `add feed`, `mark all read`) lets external scripts change the store and needs explicit sign-off. Adding `OSAScriptingDefinition` + bundling `.sdef` is a `.pbxproj`/Info.plist edit (Xcode closed); no new entitlement to *be* scriptable.

**Behaviour**
- **OQ-11:** Reader (A1) — should card tap default to the in-app Reader (plan default, reversible via `@AppStorage`) or stay browser-open with Reader via context menu/toolbar?
- **OQ-12:** Reader rendering fidelity (A1) — plain-text (no-dep, dark-only) accepted, or is rich rendering (inline images/links) wanted? Rich effectively needs WKWebView with an injected dark stylesheet — brushes the dark-only invariant and adds WebKit/UIKit surface. *Flagged as a dependency-shaped decision.*
- **OQ-13:** Dark Mode (A3) — confirm no true Light mode now (only System/Dark, both → dark). A real Light mode is a separate, larger cluster.
- **OQ-14:** "Today" (D2) definition — calendar-day start (device timezone, plan default) vs rolling 24 h; and must it auto-roll at midnight or is a view re-init acceptable for v1?
- **OQ-15:** Keyboard (B2) — wrap vs clamp at list ends (plan: clamp); auto-advance selection after `m`/open (plan: advance on `m`, stay on open)?
- **OQ-16:** Multi-window (F2) — restore previously-open windows on relaunch, or always launch a single default window?

**Third-party-dependency temptations (all declined to honour the no-dep rule — listed for transparency):** WKWebView/HTML-renderer for the Reader (OQ-12), any RSS/OPML/HTML-parsing library (use existing `XMLParser`/regex seams), any JS library inside the Safari extension (vanilla JS only). **No new Swift package is proposed by any cluster.**

---

## 8. Phase 2 bug-sweep checklist

A dedicated post-implementation sweep (separate pass) will confirm:

- **Build clean in Xcode** — full clean build of the Discover scheme on "My Mac" with **no new warnings**; verify in Xcode, not only sandbox `xcodebuild` (macro expansion can fail in restricted environments).
- **Warnings-as-errors** — build once with strict warnings escalated; resolve every new diagnostic introduced by the feature work.
- **SwiftData migration check** — launch against a **populated existing on-disk store** and confirm the 3 added properties + `FolderModel` migrate via lightweight migration **without resetting** existing Articles/Feeds/Categories or read-state (guards OQ-1); confirm the in-memory fallback path still works.
- **Force-unwrap / retain-cycle / main-actor audit** — scan new code for `!` force-unwraps and `try?` silent swallows (must use `saveOrLog`/surfaced errors); check closures for retain cycles (`[weak self]` where needed); confirm all ViewModels/managers/SwiftData access are `@MainActor` and all cross-actor types are explicitly `Sendable` with no uncommented `@unchecked`.
- **Dead code** — remove any superseded inline open/mark-read/refresh-loop code left behind after extraction into `ArticleActions`/`ArticleOpener`/`ArticleUpsertService`/`RefreshScheduler`; remove unused params/imports.
- **Crash-on-launch** — cold launch (fresh store) and warm launch (existing store), plus launch with App Group entitlement absent (G must degrade, not crash) and with the on-disk store deliberately corrupted (in-memory fallback).
- **Tests green twice** — run the full Swift Testing suite **twice** (`Cmd+U`) to catch order-dependence/flakiness (esp. clock-sensitive Today/refresh tests and concurrent-append inbox tests); confirm the previously-missing fixtures no longer fail.
