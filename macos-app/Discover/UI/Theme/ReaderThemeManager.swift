import SwiftUI

/// Owns the Reader's typography theme (cluster A2) and the app appearance (cluster A3).
///
/// `@Observable @MainActor`: it is the **single owner** of its `UserDefaults` keys, so
/// PreferencesView binds to this manager rather than declaring duplicate `@AppStorage`
/// properties for the same keys. Injected once from `DiscoverApp` via `.environment`.
///
/// State is kept as `@AppStorage`-compatible primitives (`Double`/`String`) persisted
/// directly to `UserDefaults`, so values round-trip across launches without a stored model.
@Observable
@MainActor
final class ReaderThemeManager {

    // MARK: - UserDefaults keys (namespaced; the manager is the single owner)
    enum Keys {
        static let fontScale  = "reader.fontScale"
        static let fontFamily = "reader.fontFamily"
        static let lineWidth  = "reader.lineWidth"
        static let appearance = "reader.appearance"
    }

    /// Allowed font-scale bounds. Values outside this range are clamped on set.
    static let minFontScale: Double = 0.8
    static let maxFontScale: Double = 1.6

    private let defaults: UserDefaults

    // MARK: - Stored, persisted properties

    /// Relative scale applied to the Reader's base body size (1.0 == default).
    var fontScale: Double {
        didSet {
            let clamped = Self.clampScale(fontScale)
            if clamped != fontScale {
                // Re-assign without re-triggering didSet recursion past one extra pass.
                fontScale = clamped
                return
            }
            defaults.set(fontScale, forKey: Keys.fontScale)
        }
    }

    /// The body typeface family.
    var fontFamily: ReaderFontFamily {
        didSet { defaults.set(fontFamily.rawValue, forKey: Keys.fontFamily) }
    }

    /// The Reader's measure (content column width).
    var lineWidth: ReaderLineWidth {
        didSet { defaults.set(lineWidth.rawValue, forKey: Keys.lineWidth) }
    }

    /// Explicit app appearance (dark-only for now; see `AppAppearance`).
    var appearance: AppAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    // MARK: - Init / hydration

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // Hydrate from primitives; absent keys fall back to sane defaults.
        let storedScale = defaults.object(forKey: Keys.fontScale) as? Double ?? 1.0
        self.fontScale = Self.clampScale(storedScale)
        self.fontFamily = ReaderFontFamily(storage: defaults.string(forKey: Keys.fontFamily) ?? "")
        self.lineWidth = ReaderLineWidth(storage: defaults.string(forKey: Keys.lineWidth) ?? "")
        self.appearance = AppAppearance(storage: defaults.string(forKey: Keys.appearance) ?? "")
    }

    // MARK: - Derived typography

    /// The `Font.Design` the Reader body should use.
    var fontDesign: Font.Design { fontFamily.design }

    /// The colour scheme to apply at the WindowGroup content root.
    var resolvedColorScheme: ColorScheme { appearance.resolvedColorScheme }

    /// Body font for the Reader at the current scale + family.
    func bodyFont(baseSize: CGFloat = 17) -> Font {
        .system(size: baseSize * fontScale, design: fontFamily.design)
    }

    /// Title font for the Reader header at the current scale + family.
    func titleFont(baseSize: CGFloat = 28) -> Font {
        .system(size: baseSize * fontScale, weight: .bold, design: fontFamily.design)
    }

    // MARK: - Helpers

    /// Clamps a font scale into the supported range.
    static func clampScale(_ value: Double) -> Double {
        min(max(value, minFontScale), maxFontScale)
    }
}

// MARK: - Reader measure (content column width)

/// The Reader's text measure — how wide the readable column is (cluster A2).
/// Stored in `@AppStorage` as the raw `String`. `Sendable` for the `@MainActor` manager.
enum ReaderLineWidth: String, CaseIterable, Identifiable, Sendable {
    case narrow
    case medium
    case wide

    var id: String { rawValue }

    var label: String {
        switch self {
        case .narrow: return "Narrow"
        case .medium: return "Medium"
        case .wide:   return "Wide"
        }
    }

    /// The maximum content width, in points, the Reader body should occupy.
    var maxContentWidth: CGFloat {
        switch self {
        case .narrow: return 560
        case .medium: return 680
        case .wide:   return 820
        }
    }

    /// Round-trips an `@AppStorage` raw value, falling back to `.medium` for unknown input.
    init(storage raw: String) {
        self = ReaderLineWidth(rawValue: raw) ?? .medium
    }
}
