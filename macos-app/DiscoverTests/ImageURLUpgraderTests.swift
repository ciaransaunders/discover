import Testing
import Foundation

@testable import Discover

@Suite("Discover — ImageURLUpgrader")
struct ImageURLUpgraderTests {

    @Test("BBC iChef width segment is bumped to high-res")
    func bbcNews() {
        #expect(ImageURLUpgrader.upgrade("https://ichef.bbci.co.uk/news/240/cpsprodpb/abc/def.jpg")
                == "https://ichef.bbci.co.uk/news/976/cpsprodpb/abc/def.jpg")
        #expect(ImageURLUpgrader.upgrade("https://ichef.bbci.co.uk/ace/standard/480/cpsprodpb/x.jpg")
                == "https://ichef.bbci.co.uk/ace/standard/976/cpsprodpb/x.jpg")
        #expect(ImageURLUpgrader.upgrade("https://ichef.bbci.co.uk/news/ws/320/x.jpg")
                == "https://ichef.bbci.co.uk/news/ws/976/x.jpg")
    }

    @Test("WordPress -WxH resize suffix is stripped to the original asset")
    func wordpress() {
        #expect(ImageURLUpgrader.upgrade("https://example.com/wp-content/uploads/2024/01/photo-150x150.jpg")
                == "https://example.com/wp-content/uploads/2024/01/photo.jpg")
        #expect(ImageURLUpgrader.upgrade("https://cdn.site.org/a/b-1024x576.webp")
                == "https://cdn.site.org/a/b.webp")
    }

    @Test("Unknown / signature-bearing / empty URLs are left unchanged")
    func noOp() {
        // Guardian URLs carry an HMAC signature — must NOT be rewritten.
        let guardianURL = "https://i.guim.co.uk/img/media/abc/master/2000.jpg?width=300&quality=85&s=deadbeef"
        #expect(ImageURLUpgrader.upgrade(guardianURL) == guardianURL)

        let plain = "https://example.com/images/hero.jpg"
        #expect(ImageURLUpgrader.upgrade(plain) == plain)

        #expect(ImageURLUpgrader.upgrade("") == "")
    }

    @Test("Upgrade is idempotent")
    func idempotent() {
        let once = ImageURLUpgrader.upgrade("https://ichef.bbci.co.uk/news/240/cpsprodpb/x.jpg")
        #expect(ImageURLUpgrader.upgrade(once) == once)
    }
}
