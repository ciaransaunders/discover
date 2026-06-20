import Testing
import SwiftUI

@testable import Discover

@Suite("Discover — AppAppearance")
struct AppAppearanceTests {

    @Test("Both cases resolve to dark (dark-only invariant)")
    func resolvesToDark() {
        #expect(AppAppearance.system.resolvedColorScheme == .dark)
        #expect(AppAppearance.dark.resolvedColorScheme == .dark)
    }

    @Test("There is no light case")
    func noLightCase() {
        let cases = AppAppearance.allCases.map(\.rawValue)
        #expect(!cases.contains("light"))
        #expect(cases.count == 2)
    }

    @Test("rawValue round-trips back to the enum")
    func roundTrip() {
        for mode in AppAppearance.allCases {
            #expect(AppAppearance(rawValue: mode.rawValue) == mode)
        }
    }

    @Test("Unknown storage value falls back to system")
    func unknownFallsBack() {
        #expect(AppAppearance(storage: "light") == .system)
        #expect(AppAppearance(storage: "") == .system)
    }

    @Test("Raw values are stable identifiers")
    func rawValues() {
        #expect(AppAppearance.system.rawValue == "system")
        #expect(AppAppearance.dark.rawValue == "dark")
    }
}
