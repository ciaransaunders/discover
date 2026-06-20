import Testing
import Foundation

@testable import Discover

@Suite("Discover — NewArticleNotifier (pure body builder)")
struct NewArticleNotifierTests {

    @Test("Zero new articles → nil (don't post)")
    func zeroIsNil() {
        #expect(NewArticleNotifier.notificationBody(forNewCount: 0) == nil)
    }

    @Test("Negative count → nil")
    func negativeIsNil() {
        #expect(NewArticleNotifier.notificationBody(forNewCount: -3) == nil)
    }

    @Test("One new article uses singular")
    func singular() {
        #expect(NewArticleNotifier.notificationBody(forNewCount: 1) == "1 new article")
    }

    @Test("Multiple new articles use plural")
    func plural() {
        #expect(NewArticleNotifier.notificationBody(forNewCount: 2) == "2 new articles")
        #expect(NewArticleNotifier.notificationBody(forNewCount: 42) == "42 new articles")
    }
}
