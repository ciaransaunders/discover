import Testing
import Foundation

@testable import Discover

@Suite("Discover — Navigation state model")
@MainActor
struct NavigationStateModelTests {

    private let ids = ["a", "b", "c"]

    // MARK: - Next stepping

    @Test("selectNext from nil lands on the first article")
    func nextFromNil() {
        let model = NavigationStateModel()
        model.selectNext(in: ids)
        #expect(model.selectedArticleID == "a")
    }

    @Test("selectNext advances one position")
    func nextAdvances() {
        let model = NavigationStateModel(selectedArticleID: "a")
        model.selectNext(in: ids)
        #expect(model.selectedArticleID == "b")
    }

    @Test("selectNext clamps at the end (does not wrap)")
    func nextClampsAtEnd() {
        let model = NavigationStateModel(selectedArticleID: "c")
        model.selectNext(in: ids)
        #expect(model.selectedArticleID == "c")
    }

    // MARK: - Previous stepping

    @Test("selectPrevious from nil lands on the first article")
    func previousFromNil() {
        let model = NavigationStateModel()
        model.selectPrevious(in: ids)
        #expect(model.selectedArticleID == "a")
    }

    @Test("selectPrevious steps back one position")
    func previousSteps() {
        let model = NavigationStateModel(selectedArticleID: "c")
        model.selectPrevious(in: ids)
        #expect(model.selectedArticleID == "b")
    }

    @Test("selectPrevious clamps at the start (does not wrap)")
    func previousClampsAtStart() {
        let model = NavigationStateModel(selectedArticleID: "a")
        model.selectPrevious(in: ids)
        #expect(model.selectedArticleID == "a")
    }

    // MARK: - Empty-list safety

    @Test("stepping over an empty list yields nil")
    func emptyListSafety() {
        let model = NavigationStateModel(selectedArticleID: "a")
        model.selectNext(in: [])
        #expect(model.selectedArticleID == nil)

        let model2 = NavigationStateModel(selectedArticleID: "a")
        model2.selectPrevious(in: [])
        #expect(model2.selectedArticleID == nil)
    }

    // MARK: - Pure stepping core

    @Test("steppedID handles bounds, nil, and empty directly")
    func steppedCore() {
        #expect(NavigationStateModel.steppedID(from: nil, in: ids, by: +1) == "a")
        #expect(NavigationStateModel.steppedID(from: "a", in: ids, by: +1) == "b")
        #expect(NavigationStateModel.steppedID(from: "c", in: ids, by: +1) == "c")
        #expect(NavigationStateModel.steppedID(from: "a", in: ids, by: -1) == "a")
        #expect(NavigationStateModel.steppedID(from: "c", in: ids, by: -1) == "b")
        #expect(NavigationStateModel.steppedID(from: "a", in: [], by: +1) == nil)
        // Stale id (not in list) → first article.
        #expect(NavigationStateModel.steppedID(from: "zzz", in: ids, by: +1) == "a")
    }

    // MARK: - Reconcile (absent-id reset)

    @Test("reconcile keeps a present selection")
    func reconcileKeepsPresent() {
        let model = NavigationStateModel(selectedArticleID: "b")
        model.reconcile(orderedIDs: ids)
        #expect(model.selectedArticleID == "b")
    }

    @Test("reconcile resets a selection no longer in the list")
    func reconcileResetsAbsent() {
        let model = NavigationStateModel(selectedArticleID: "b")
        model.reconcile(orderedIDs: ["a", "c"])  // b purged/filtered away
        #expect(model.selectedArticleID == nil)
    }

    @Test("reconcile resets when the list becomes empty")
    func reconcileResetsOnEmpty() {
        let model = NavigationStateModel(selectedArticleID: "a")
        model.reconcile(orderedIDs: [])
        #expect(model.selectedArticleID == nil)
    }

    @Test("reconcile is a no-op when nothing is selected")
    func reconcileNoSelection() {
        let model = NavigationStateModel()
        model.reconcile(orderedIDs: ids)
        #expect(model.selectedArticleID == nil)
    }

    // MARK: - clear

    @Test("clear nils the selection")
    func clearSelection() {
        let model = NavigationStateModel(selectedArticleID: "b")
        model.clear()
        #expect(model.selectedArticleID == nil)
    }
}

// MARK: - Category cycling (pure, no MainActor needed)

@Suite("Discover — Category cycling")
struct CategoryCyclerTests {

    private let slugs = ["ai", "tech", "gaming"]

    // MARK: - Forward

    @Test("next from .all enters at the first category")
    func nextFromAll() {
        #expect(CategoryCycler.next(after: .all, slugs: slugs) == .category("ai"))
    }

    @Test("next advances through the categories")
    func nextAdvances() {
        #expect(CategoryCycler.next(after: .category("ai"), slugs: slugs) == .category("tech"))
        #expect(CategoryCycler.next(after: .category("tech"), slugs: slugs) == .category("gaming"))
    }

    @Test("next from the last category wraps to .all")
    func nextWrapsToAll() {
        #expect(CategoryCycler.next(after: .category("gaming"), slugs: slugs) == .all)
    }

    // MARK: - Backward

    @Test("previous from .all wraps to the last category")
    func previousFromAll() {
        #expect(CategoryCycler.previous(before: .all, slugs: slugs) == .category("gaming"))
    }

    @Test("previous steps back through the categories")
    func previousSteps() {
        #expect(CategoryCycler.previous(before: .category("gaming"), slugs: slugs) == .category("tech"))
        #expect(CategoryCycler.previous(before: .category("tech"), slugs: slugs) == .category("ai"))
    }

    @Test("previous from the first category wraps to .all")
    func previousWrapsToAll() {
        #expect(CategoryCycler.previous(before: .category("ai"), slugs: slugs) == .all)
    }

    // MARK: - Smart feeds / folders enter the ring gracefully

    @Test("cycling forward from a smart feed enters at the first category")
    func nextFromSmartFeed() {
        #expect(CategoryCycler.next(after: .allUnread, slugs: slugs) == .category("ai"))
        #expect(CategoryCycler.next(after: .today, slugs: slugs) == .category("ai"))
        #expect(CategoryCycler.next(after: .starred, slugs: slugs) == .category("ai"))
    }

    @Test("cycling backward from a smart feed jumps to the last category")
    func previousFromSmartFeed() {
        #expect(CategoryCycler.previous(before: .allUnread, slugs: slugs) == .category("gaming"))
    }

    @Test("cycling from a folder enters the category ring")
    func cycleFromFolder() {
        let folder = SidebarSelection.folder(slug: "f", feedUrls: [])
        #expect(CategoryCycler.next(after: folder, slugs: slugs) == .category("ai"))
        #expect(CategoryCycler.previous(before: folder, slugs: slugs) == .category("gaming"))
    }

    // MARK: - Unknown slug

    @Test("an unknown slug restarts/wraps the ring rather than getting stuck")
    func unknownSlug() {
        #expect(CategoryCycler.next(after: .category("ghost"), slugs: slugs) == .category("ai"))
        #expect(CategoryCycler.previous(before: .category("ghost"), slugs: slugs) == .category("gaming"))
    }

    // MARK: - Empty categories

    @Test("with no categories every result is .all")
    func emptyCategories() {
        #expect(CategoryCycler.next(after: .all, slugs: []) == .all)
        #expect(CategoryCycler.previous(before: .all, slugs: []) == .all)
        #expect(CategoryCycler.next(after: .category("ai"), slugs: []) == .all)
        #expect(CategoryCycler.next(after: .allUnread, slugs: []) == .all)
    }
}
