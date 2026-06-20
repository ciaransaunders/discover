import SwiftUI
import SwiftData

/// The main content panel: hero card + adaptive grid of article cards.
/// Reads live data from SwiftData via `@Query` and refreshes via
/// `ArticleListViewModel` (which delegates network work to `RSSFetcherActor`).
struct ArticleListView: View {

    // MARK: - Inputs

    let selection: SidebarSelection

    /// Cluster B2 — write-back binding so category cycling (Tab / `[` / `]`) can change the parent's
    /// selection. The value-typed `selection` above still drives the `@Query` built in `init`.
    @Binding var selectionBinding: SidebarSelection

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext

    /// Cluster B1 — shared selected-article state (owned by `ContentView`, injected via `.environment`).
    @Environment(NavigationStateModel.self) private var navState

    // MARK: - State

    @AppStorage("recentSearches") private var recentSearchesJSON: String = "[]"
    /// Cluster C2 — hide already-read articles from the list (view-layer only, no schema).
    @AppStorage("hideReadArticles") private var hideReadArticles = false
    /// Cluster B2 — open path for space/return must match the card tap (Reader vs browser).
    @AppStorage("tapOpensReader") private var tapOpensReader = true
    @AppStorage("markReadOnOpen") private var markReadOnOpen = true
    @AppStorage("openLinksInBackground") private var openInBackground = false

    @State private var viewModel   = ArticleListViewModel()
    @State private var showFeedMgr = false
    @State private var searchText  = ""
    /// Debounced copy of `searchText` (updated ~250 ms after the last keystroke).
    @State private var committedSearch = ""
    @State private var searchScope: ArticleSearchScope = .all
    @State private var setupErrorMessage: String?

    // MARK: - Keyboard navigation (cluster B)

    /// Focus target for the article scroll region. Single-key nav is handled **only** while this is
    /// focused and the `.searchable` field is not, so text input keeps working.
    @FocusState private var listFocused: Bool
    /// Article presented in the keyboard-driven Reader sheet (space/return when `tapOpensReader`).
    @State private var keyboardReaderArticle: ArticleModel?

    // MARK: - Data (dynamic @Query predicate from the SidebarSelection)

    @Query private var articles: [ArticleModel]

    /// All categories — used to build the slug → hex colour lookup for card badges.
    @Query(sort: \CategoryModel.priority) private var allCategories: [CategoryModel]

    /// Enabled feeds and their `lastError` values are used to show offline/failed UI.
    @Query(sort: \FeedModel.name) private var feeds: [FeedModel]

    /// Folders — used to resolve the nav title for a `.folder` selection to its stored name.
    @Query(sort: \FolderModel.priority) private var folders: [FolderModel]

    // Grid layout: adaptive columns, minimum 280 pt wide.
    private let columns = [GridItem(.adaptive(minimum: 280, maximum: 380), spacing: 16)]

    /// For `.folder`, the resolved member feed URLs (carried in the selection). The folder query is
    /// unfiltered (OQ-2) and membership is applied in-memory in `displayedArticles` from these.
    private let folderFeedUrls: [String]

    // MARK: - Init (dynamic @Query predicate per selection)

    init(selection: SidebarSelection, selectionBinding: Binding<SidebarSelection> = .constant(.all)) {
        self.selection = selection
        self._selectionBinding = selectionBinding
        let sort = [SortDescriptor(\ArticleModel.publishedAt, order: .reverse)]

        switch selection {
        case .all:
            self.folderFeedUrls = []
            _articles = Query(sort: sort)
        case .allUnread:
            self.folderFeedUrls = []
            _articles = Query(filter: SmartFeedPredicates.unread(), sort: sort)
        case .today:
            // Capture the Date in a `let` BEFORE the macro (same pattern as purgeOldArticles).
            self.folderFeedUrls = []
            _articles = Query(filter: SmartFeedPredicates.today(), sort: sort)
        case .starred:
            self.folderFeedUrls = []
            _articles = Query(filter: SmartFeedPredicates.starred(), sort: sort)
        case .category(let slug):
            self.folderFeedUrls = []
            _articles = Query(filter: SmartFeedPredicates.category(slug), sort: sort)
        case .folder(_, let feedUrls):
            // OQ-2: the folder `#Predicate` (Array.contains + optional-coalescing) throws at fetch
            // time, so the query is unfiltered and membership is applied in `displayedArticles`.
            self.folderFeedUrls = feedUrls
            _articles = Query(sort: sort)
        }
    }

    // MARK: - Computed

    /// Slug → hex colour lookup built from persisted CategoryModel rows.
    private var categoryColorMap: [String: String] {
        Dictionary(uniqueKeysWithValues: allCategories.map { ($0.slug, $0.colorHex) })
    }

    /// The category slug the active selection scopes to, for the "This Category" search scope.
    /// Smart feeds and folders are not category-scoped, so this is `nil` there.
    private var scopedCategory: String? {
        if case .category(let slug) = selection { return slug }
        return nil
    }

    /// Articles for display: `@Query` results filtered (in order) by the debounced search query +
    /// scope, then the defensive folder-membership fallback, then the "hide read" preference.
    ///
    /// Uses the pure `ArticleSearchMatcher` (cluster E) and `ArticleVisibilityFilter` (cluster C2)
    /// so all three behaviours are unit-tested. Each stage composes with the previous one.
    private var displayedArticles: [ArticleModel] {
        var result = searchFilteredArticles

        // Folder membership (FEATURE_PLAN OQ-2): resolved in memory because the SwiftData
        // `#Predicate` form throws at fetch time. Shares the pure `articleIsInFolder` rule.
        if case .folder = selection {
            let allowed = Set(folderFeedUrls)
            result = result.filter { SmartFeedPredicates.articleIsInFolder($0, feedUrls: allowed) }
        }

        // Cluster C2 — drop read articles when "Hide read" is on.
        result = ArticleVisibilityFilter.visible(result, hideRead: hideReadArticles) { $0.isRead }

        return result
    }

    /// The `@Query` results filtered by the debounced search query + scope (in-memory).
    /// An empty query under the `.all` scope short-circuits to the unfiltered list.
    private var searchFilteredArticles: [ArticleModel] {
        let trimmed = committedSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty, searchScope == .all { return articles }
        return articles.filter { article in
            ArticleSearchMatcher.matches(
                ArticleSearchSubject(
                    title: article.title,
                    snippet: article.snippet,
                    source: article.source,
                    category: article.category,
                    isRead: article.isRead
                ),
                query: committedSearch,
                scope: searchScope,
                selectedCategory: scopedCategory
            )
        }
    }

    /// Recent search terms decoded from `@AppStorage` JSON.
    private var recentSearches: [String] {
        RecentSearchesStore.decode(recentSearchesJSON)
    }

    // MARK: - Keyboard selection (cluster B)

    /// The selection order for keyboard navigation — the same `displayedArticles` everything else
    /// uses (single source of truth), reduced to stable ids.
    private var orderedIDs: [String] {
        displayedArticles.map(\.id)
    }

    /// Resolve the selected article by id against the current `displayedArticles` (so a purged /
    /// filtered-out id never points at an off-screen article). `nil` when nothing is selected.
    private var selectedArticle: ArticleModel? {
        guard let id = navState.selectedArticleID else { return nil }
        return displayedArticles.first { $0.id == id }
    }

    // MARK: - Body

    var body: some View {
        articleScroll
        // Extend content under navigation bar for Liquid Glass scroll-edge effect.
        .scrollContentBackground(.hidden)
        .searchable(text: $searchText, prompt: "Search articles…")
        .searchScopes($searchScope) {
            ForEach(ArticleSearchScope.allCases) { scope in
                Text(scope.label).tag(scope)
            }
        }
        .searchSuggestions {
            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ForEach(recentSearches, id: \.self) { term in
                    Text(term).searchCompletion(term)
                }
            }
        }
        .onSubmit(of: .search) {
            recordRecentSearch(searchText)
        }
        .navigationTitle(navTitle)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // Hide-read quick toggle (cluster C2).
                Button {
                    hideReadArticles.toggle()
                } label: {
                    Label(
                        hideReadArticles ? "Show Read" : "Hide Read",
                        systemImage: hideReadArticles ? "eye.slash.fill" : "eye.slash"
                    )
                }
                .help(hideReadArticles ? "Show read articles" : "Hide read articles")

                // Mark All Read button
                Button {
                    markAllRead()
                } label: {
                    Label("Mark All Read", systemImage: "checkmark.circle")
                }
                .disabled(displayedArticles.allSatisfy(\.isRead))

                // Feed Manager button
                Button { showFeedMgr = true } label: {
                    Label("Feeds", systemImage: "dot.radiowaves.up.forward")
                }

                // Refresh button
                Button {
                    Task { await viewModel.refresh(context: modelContext) }
                } label: {
                    if viewModel.isRefreshing {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(viewModel.isRefreshing)
            }

            // Last-refreshed timestamp — use the same compact relative format as cards
            if let ts = viewModel.lastRefreshed {
                ToolbarItem(placement: .status) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                            .font(.caption2)
                        TimeAgoText(date: ts)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        // Seed defaults (idempotent) so an empty category never shows up un-seeded. The
        // app-lifetime background refresh loop + initial fetch are owned by `RefreshScheduler`
        // in `ContentView` (cluster E2) — this view no longer runs its own refresh timer.
        .task {
            do {
                try DefaultFeedsSeeder.seedIfNeeded(context: modelContext)
            } catch {
                setupErrorMessage = error.localizedDescription
            }
        }
        // Debounce the search field into a committed query that drives the in-memory filter.
        .task(id: searchText) {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            committedSearch = searchText
        }
        // ⌘R refresh notification
        .onReceive(NotificationCenter.default.publisher(for: .refreshFeeds)) { _ in
            Task { await viewModel.refresh(context: modelContext) }
        }
        // ⌘⇧R force refresh notification
        .onReceive(NotificationCenter.default.publisher(for: .forceRefreshFeeds)) { _ in
            Task { await viewModel.forceRefresh(context: modelContext) }
        }
        // Feed Manager sheet.
        .sheet(isPresented: $showFeedMgr) {
            FeedManagerView()
        }
        // Cluster B2 — keyboard-driven Reader (space/return when `tapOpensReader`), mirroring card tap.
        .sheet(item: $keyboardReaderArticle) { article in
            ReaderView(article: article, colorHex: categoryColorMap[article.category] ?? "#6B7280")
        }
        // Error alert.
        .alert("Refresh failed", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert("Setup failed", isPresented: Binding(
            get: { setupErrorMessage != nil },
            set: { if !$0 { setupErrorMessage = nil } }
        )) {
            Button("OK") { setupErrorMessage = nil }
        } message: {
            Text(setupErrorMessage ?? "")
        }
    }

    // MARK: - Article scroll region (focusable, keyboard-navigable)

    /// The scrollable hero + grid, wrapped so keyboard selection (cluster B) can scroll the selected
    /// article into view and (on macOS) route single-key shortcuts. The region is the focus target;
    /// nav keys are handled only while it is focused (and the search field is not).
    private var articleScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        feedStatusBanner
                            .padding(.horizontal, 16)
                    }
                    if displayedArticles.isEmpty {
                        emptyState
                    } else {
                        // Hero card — first (most recent) article.
                        let hero = displayedArticles[0]
                        HeroCardView(
                            article: hero,
                            colorHex: categoryColorMap[hero.category] ?? "#6B7280",
                            isSelected: navState.selectedArticleID == hero.id
                        )
                        .id(hero.id)
                        .padding(.horizontal, 16)

                        // Adaptive grid — the rest.
                        if displayedArticles.count > 1 {
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(displayedArticles.dropFirst()) { article in
                                    ArticleCardView(
                                        article: article,
                                        colorHex: categoryColorMap[article.category] ?? "#6B7280",
                                        isSelected: navState.selectedArticleID == article.id
                                    )
                                    .id(article.id)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            // Keep the selection resolvable: if the selected id has left `displayedArticles`
            // (purged / filtered / searched away), reset to nil. Runs each time the list changes.
            .onChange(of: orderedIDs) { _, ids in
                navState.reconcile(orderedIDs: ids)
            }
            // Scroll the selected card into view as keyboard selection moves.
            .onChange(of: navState.selectedArticleID) { _, id in
                guard let id else { return }
                withAnimation(.easeInOut(duration: 0.18)) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
            #if os(macOS)
            // Make the scroll region the focus target and route NetNewsWire-style single keys.
            // Keys we don't own (or anything with ⌘) return `.ignored` so text fields/buttons work.
            .focusable()
            .focused($listFocused)
            .focusEffectDisabled()
            .onKeyPress { press in
                handleKeyPress(press)
            }
            #endif
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: searchText.isEmpty ? "newspaper" : "magnifyingglass")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text(searchText.isEmpty ? "No articles yet" : "No results for \u{201C}\(searchText)\u{201D}")
                .font(.title2.bold())
            if searchText.isEmpty {
                if isOffline {
                    Text("You appear to be offline. Check your connection and try refreshing.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } else if !failedFeeds.isEmpty {
                    Text("\(failedFeeds.count) feed\(failedFeeds.count == 1 ? "" : "s") failed to refresh. Open Feeds to see which ones.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Tap ⌘R to fetch the latest news from your feeds.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                Button("Refresh Now") {
                    Task { await viewModel.refresh(context: modelContext) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isRefreshing)
                Button("Open Feeds") {
                    showFeedMgr = true
                }
            } else {
                Text("Try a different search term, or clear the search to see all articles.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: - Actions

    private func markAllRead() {
        for article in displayedArticles where !article.isRead {
            article.isRead = true
        }
        do {
            try modelContext.save()
        } catch {
            setupErrorMessage = error.localizedDescription
        }
    }

    // MARK: - Keyboard routing (cluster B2)

    #if os(macOS)
    /// The single `.onKeyPress` router for the focusable list region.
    ///
    /// Maps the press through the pure `ArticleKeyCommands` mapper; unowned keys (and anything with
    /// ⌘) return `.ignored` so menu shortcuts, default activation, and any focused control keep their
    /// keys. We never claim a key while the keyboard Reader sheet is open.
    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        guard keyboardReaderArticle == nil else { return .ignored }
        guard let command = ArticleKeyCommands.command(for: press.key, modifiers: press.modifiers) else {
            return .ignored
        }
        perform(command)
        return .handled
    }

    /// Interprets a resolved `ArticleKeyCommand` against the current `displayedArticles` / selection.
    private func perform(_ command: ArticleKeyCommand) {
        switch command {
        case .nextArticle:
            navState.selectNext(in: orderedIDs)
        case .previousArticle:
            navState.selectPrevious(in: orderedIDs)
        case .openSelection:
            openSelectedArticle()
        case .toggleRead:
            if let article = selectedArticle {
                ArticleActions.toggleRead(article, context: modelContext)
            }
        case .markReadAndAdvance:
            if let article = selectedArticle {
                ArticleActions.markRead(article, context: modelContext)
                navState.selectNext(in: orderedIDs)
            }
        case .markUnread:
            if let article = selectedArticle {
                ArticleActions.markUnread(article, context: modelContext)
            }
        case .nextCategory:
            selectionBinding = CategoryCycler.next(after: selectionBinding, slugs: orderedCategorySlugs)
        case .previousCategory:
            selectionBinding = CategoryCycler.previous(before: selectionBinding, slugs: orderedCategorySlugs)
        case .clearSelection:
            navState.clear()
        }
    }

    /// Ordered category slugs the cycler ('[' / ']' / Tab) walks — same order as the sidebar.
    private var orderedCategorySlugs: [String] {
        allCategories.map(\.slug)
    }

    /// Open the selected article via the SAME decision as a card tap: Reader if `tapOpensReader`,
    /// else the external browser through the shared `ArticleOpener`.
    private func openSelectedArticle() {
        guard let article = selectedArticle else { return }
        if tapOpensReader {
            keyboardReaderArticle = article
        } else {
            ArticleOpener.openInBrowser(
                article,
                markRead: markReadOnOpen,
                inBackground: openInBackground,
                context: modelContext
            )
        }
    }
    #endif

    // MARK: - Recent searches (cluster E3)

    /// Promotes `term` to the recent-searches list (de-duplicated, bounded) and persists it.
    private func recordRecentSearch(_ term: String) {
        let updated = RecentSearchesStore.adding(term, to: recentSearches)
        recentSearchesJSON = RecentSearchesStore.encode(updated)
    }

    // MARK: - Feed status

    private var enabledFeeds: [FeedModel] {
        feeds.filter(\.enabled)
    }

    private var failedFeeds: [FeedModel] {
        enabledFeeds.filter { ($0.lastError?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) }
    }

    private var isOffline: Bool {
        guard !enabledFeeds.isEmpty, failedFeeds.count == enabledFeeds.count else { return false }
        return failedFeeds.allSatisfy { ($0.lastError ?? "").localizedCaseInsensitiveContains("offline") }
    }

    @ViewBuilder
    private var feedStatusBanner: some View {
        if !failedFeeds.isEmpty {
            let title = isOffline ? "Offline" : "Some feeds failed"
            let subtitle: String = {
                if isOffline { return "Check your connection and refresh." }
                let count = failedFeeds.count
                let names = failedFeeds.prefix(3).map(\.name)
                let suffix = count > 3 ? " (+\(count - 3) more)" : ""
                return "\(count) failed: \(names.joined(separator: ", "))\(suffix)"
            }()

            HStack(spacing: 10) {
                Image(systemName: isOffline ? "wifi.slash" : "exclamationmark.triangle.fill")
                    .foregroundStyle(isOffline ? Color.secondary : Color.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer(minLength: 8)

                HStack(spacing: 8) {
                    Button {
                        Task { await viewModel.refreshFailedFeeds(context: modelContext) }
                    } label: {
                        if viewModel.isRefreshing {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Retry")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isRefreshing)

                    Button("Feeds") { showFeedMgr = true }
                        .buttonStyle(.bordered)
                }
            }
            .padding(12)
            .glassCard(cornerRadius: 14)
        }
    }

    // MARK: - Helpers

    /// Navigation title for the active selection. Prefers the stored `CategoryModel.label` /
    /// `FolderModel.name`, falling back to `SidebarSelection.title` (capitalised slug / fixed name).
    private var navTitle: String {
        let categoryLabels = Dictionary(uniqueKeysWithValues: allCategories.map { ($0.slug, $0.label) })
        let folderNames = Dictionary(uniqueKeysWithValues: folders.map { ($0.slug, $0.name) })
        return selection.resolvedTitle(
            categoryLabel: { categoryLabels[$0] },
            folderName: { folderNames[$0] }
        )
    }
}
