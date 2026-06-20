import Testing
import SwiftUI

@testable import Discover

@Suite("Discover — ReaderFontFamily")
struct ReaderFontFamilyTests {

    @Test("Raw values are stable lowercase identifiers")
    func rawValues() {
        #expect(ReaderFontFamily.system.rawValue == "system")
        #expect(ReaderFontFamily.serif.rawValue == "serif")
        #expect(ReaderFontFamily.mono.rawValue == "mono")
    }

    @Test("rawValue round-trips back to the enum")
    func roundTrip() {
        for family in ReaderFontFamily.allCases {
            #expect(ReaderFontFamily(rawValue: family.rawValue) == family)
        }
    }

    @Test("Unknown storage value falls back to system")
    func unknownFallsBack() {
        #expect(ReaderFontFamily(storage: "comic-sans") == .system)
        #expect(ReaderFontFamily(storage: "") == .system)
    }

    @Test("Maps to the correct Font.Design")
    func designMapping() {
        #expect(ReaderFontFamily.system.design == .default)
        #expect(ReaderFontFamily.serif.design == .serif)
        #expect(ReaderFontFamily.mono.design == .monospaced)
    }

    @Test("All cases are enumerable")
    func allCases() {
        #expect(ReaderFontFamily.allCases.count == 3)
    }
}

@Suite("Discover — ReaderLineWidth")
struct ReaderLineWidthTests {

    @Test("rawValue round-trips back to the enum")
    func roundTrip() {
        for width in ReaderLineWidth.allCases {
            #expect(ReaderLineWidth(rawValue: width.rawValue) == width)
        }
    }

    @Test("Unknown storage value falls back to medium")
    func unknownFallsBack() {
        #expect(ReaderLineWidth(storage: "ultra") == .medium)
    }

    @Test("Widths are monotonically increasing")
    func widthsIncrease() {
        #expect(ReaderLineWidth.narrow.maxContentWidth < ReaderLineWidth.medium.maxContentWidth)
        #expect(ReaderLineWidth.medium.maxContentWidth < ReaderLineWidth.wide.maxContentWidth)
    }
}
