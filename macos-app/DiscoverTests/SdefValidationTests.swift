import Testing
import Foundation

@testable import Discover

private final class SdefBundleToken {}

/// Cluster F3 — the bundled `Discover.sdef` must be well-formed XML and must declare the four
/// elements that make up the minimal v1 AppleScript surface (OQ-10): the two read-only properties
/// (`unread count`, `article count`) and the two action commands (`refresh feeds`,
/// `force refresh feeds`).
///
/// The file is loaded from the test bundle if present, otherwise from its known source path (the
/// resource is shared with the app target; either route exercises the same on-disk file).
@Suite("Discover — Discover.sdef validation")
struct SdefValidationTests {

    /// Resolves the `.sdef` URL: prefer the test bundle, fall back to the source tree path derived
    /// from `#filePath` (DiscoverTests/… → Discover/Resources/Discover.sdef).
    private func sdefURL() -> URL? {
        if let url = Bundle(for: SdefBundleToken.self).url(forResource: "Discover", withExtension: "sdef") {
            return url
        }
        // Fallback: …/macos-app/DiscoverTests/SdefValidationTests.swift → …/macos-app/Discover/Resources/Discover.sdef
        let here = URL(fileURLWithPath: #filePath)            // …/DiscoverTests/SdefValidationTests.swift
        let macosApp = here.deletingLastPathComponent()       // …/DiscoverTests
            .deletingLastPathComponent()                      // …/macos-app
        let candidate = macosApp
            .appendingPathComponent("Discover")
            .appendingPathComponent("Resources")
            .appendingPathComponent("Discover.sdef")
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
    }

    @Test("the .sdef file exists")
    func fileExists() throws {
        let url = try #require(sdefURL(), "Discover.sdef not found in bundle or source tree")
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test("the .sdef is well-formed XML")
    func wellFormedXML() throws {
        let url = try #require(sdefURL())
        let data = try Data(contentsOf: url)
        // XMLDocument throws if the document is not well-formed.
        let doc = try XMLDocument(data: data, options: [])
        #expect(doc.rootElement()?.name == "dictionary")
    }

    @Test("declares the two action commands")
    func declaresCommands() throws {
        let url = try #require(sdefURL())
        let xml = try String(contentsOf: url, encoding: .utf8)
        #expect(xml.contains("name=\"refresh feeds\""))
        #expect(xml.contains("name=\"force refresh feeds\""))
    }

    @Test("declares the two read-only count properties")
    func declaresProperties() throws {
        let url = try #require(sdefURL())
        let xml = try String(contentsOf: url, encoding: .utf8)
        #expect(xml.contains("name=\"unread count\""))
        #expect(xml.contains("name=\"article count\""))
    }

    @Test("contains exactly the four minimal-surface elements (commands + properties)")
    func fourElements() throws {
        let url = try #require(sdefURL())
        let data = try Data(contentsOf: url)
        let doc = try XMLDocument(data: data, options: [])

        let commands = try doc.nodes(forXPath: "//command")
        let properties = try doc.nodes(forXPath: "//property")
        #expect(commands.count == 2)
        #expect(properties.count == 2)
    }

    @Test("command cocoa classes reference the Swift command subclasses")
    func cocoaClasses() throws {
        let url = try #require(sdefURL())
        let xml = try String(contentsOf: url, encoding: .utf8)
        #expect(xml.contains("Discover.RefreshFeedsCommand"))
        #expect(xml.contains("Discover.ForceRefreshFeedsCommand"))
    }

    @Test("AppleEvent 4-char codes are unique")
    func uniqueCodes() throws {
        let url = try #require(sdefURL())
        let data = try Data(contentsOf: url)
        let doc = try XMLDocument(data: data, options: [])

        // Collect every `code` attribute on command/property nodes (the AppleEvent codes that must
        // not collide). Suite/class codes are standard ("Disc"/"capp") and excluded.
        let nodes = try doc.nodes(forXPath: "//command/@code") + doc.nodes(forXPath: "//property/@code")
        let codes = nodes.compactMap { $0.stringValue }
        #expect(codes.count == 4)
        #expect(Set(codes).count == codes.count, "duplicate AppleEvent code: \(codes)")
    }
}
