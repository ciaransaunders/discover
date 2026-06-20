import Testing
import Foundation

@testable import Discover

@Suite("Discover — ReaderThemeManager")
@MainActor
struct ReaderThemeManagerTests {

    /// A throwaway `UserDefaults` suite so tests never touch the real app domain.
    private func makeDefaults() -> UserDefaults {
        let name = "ReaderThemeManagerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("Sane defaults when nothing is stored")
    func defaults() {
        let manager = ReaderThemeManager(defaults: makeDefaults())
        #expect(manager.fontScale == 1.0)
        #expect(manager.fontFamily == .system)
        #expect(manager.lineWidth == .medium)
        #expect(manager.appearance == .system)
    }

    @Test("Values persist and round-trip through a fresh manager")
    func persistenceRoundTrip() {
        let defaults = makeDefaults()
        let first = ReaderThemeManager(defaults: defaults)
        first.fontScale = 1.3
        first.fontFamily = .serif
        first.lineWidth = .wide
        first.appearance = .dark

        let second = ReaderThemeManager(defaults: defaults)
        #expect(second.fontScale == 1.3)
        #expect(second.fontFamily == .serif)
        #expect(second.lineWidth == .wide)
        #expect(second.appearance == .dark)
    }

    @Test("fontScale clamps above the maximum")
    func clampHigh() {
        let manager = ReaderThemeManager(defaults: makeDefaults())
        manager.fontScale = 5.0
        #expect(manager.fontScale == ReaderThemeManager.maxFontScale)
    }

    @Test("fontScale clamps below the minimum")
    func clampLow() {
        let manager = ReaderThemeManager(defaults: makeDefaults())
        manager.fontScale = 0.1
        #expect(manager.fontScale == ReaderThemeManager.minFontScale)
    }

    @Test("Out-of-range stored scale is clamped on hydration")
    func clampOnHydration() {
        let defaults = makeDefaults()
        defaults.set(99.0, forKey: ReaderThemeManager.Keys.fontScale)
        let manager = ReaderThemeManager(defaults: defaults)
        #expect(manager.fontScale == ReaderThemeManager.maxFontScale)
    }

    @Test("bodyFont and titleFont scale with fontScale (no crash)")
    func fontsBuild() {
        let manager = ReaderThemeManager(defaults: makeDefaults())
        manager.fontScale = 1.2
        // Smoke test: building fonts must not crash and design must follow family.
        _ = manager.bodyFont()
        _ = manager.titleFont()
        manager.fontFamily = .mono
        #expect(manager.fontDesign == .monospaced)
    }
}
