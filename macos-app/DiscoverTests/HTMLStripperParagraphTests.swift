import Testing
import Foundation

@testable import Discover

@Suite("Discover — HTMLStripper paragraph mode")
struct HTMLStripperParagraphTests {

    @Test("Splits multiple <p> blocks into separate paragraphs")
    func splitsParagraphs() {
        let html = "<p>First paragraph.</p><p>Second paragraph.</p>"
        #expect(HTMLStripper.paragraphs(html) == ["First paragraph.", "Second paragraph."])
    }

    @Test("Splits on <br> boundaries")
    func splitsOnBreaks() {
        let html = "Line one<br>Line two<br/>Line three"
        #expect(HTMLStripper.paragraphs(html) == ["Line one", "Line two", "Line three"])
    }

    @Test("Decodes HTML entities within paragraphs")
    func decodesEntities() {
        let html = "<p>Tom &amp; Jerry &lt;3 &#39;news&#39;</p>"
        #expect(HTMLStripper.paragraphs(html) == ["Tom & Jerry <3 'news'"])
    }

    @Test("Strips inline tags but keeps inline text")
    func stripsInlineTags() {
        let html = "<p>A <strong>bold</strong> and <em>italic</em> word.</p>"
        #expect(HTMLStripper.paragraphs(html) == ["A bold and italic word."])
    }

    @Test("Drops empty / whitespace-only paragraphs")
    func dropsEmpty() {
        let html = "<p>Real.</p><p></p><p>   </p><p>Also real.</p>"
        #expect(HTMLStripper.paragraphs(html) == ["Real.", "Also real."])
    }

    @Test("Returns empty array for empty input")
    func emptyInput() {
        #expect(HTMLStripper.paragraphs("") == [])
    }

    @Test("Plain text with no block tags yields a single paragraph")
    func plainText() {
        #expect(HTMLStripper.paragraphs("Just some text.") == ["Just some text."])
    }

    @Test("Handles list items as separate paragraphs")
    func listItems() {
        let html = "<ul><li>One</li><li>Two</li></ul>"
        #expect(HTMLStripper.paragraphs(html) == ["One", "Two"])
    }

    @Test("Does not crash on malformed / unbalanced markup")
    func malformedNoCrash() {
        // Numeric entity at the very end + unbalanced tags previously risked index crashes.
        let html = "<p>Unclosed and a entity &#8230;<div>broken"
        let paragraphs = HTMLStripper.paragraphs(html)
        // Just assert it returns something sane without crashing.
        #expect(!paragraphs.isEmpty)
        #expect(paragraphs.first?.contains("Unclosed") == true)
    }
}
