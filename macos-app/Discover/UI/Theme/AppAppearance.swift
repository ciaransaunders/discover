import SwiftUI

/// Explicit app-appearance control (cluster A3).
///
/// The owner decision is **dark-only**: `light` is deliberately omitted so a future Light
/// mode is a purely additive change. Both `system` and `dark` currently resolve to `.dark`.
/// Stored in `@AppStorage` as the raw `String`; `Sendable` for the `@MainActor` manager.
enum AppAppearance: String, CaseIterable, Identifiable, Sendable {
    case system
    case dark

    var id: String { rawValue }

    /// Human-readable label for the appearance picker.
    var label: String {
        switch self {
        case .system: return "System"
        case .dark:   return "Dark"
        }
    }

    /// The `ColorScheme` to apply via `.preferredColorScheme`.
    ///
    /// Both cases resolve to `.dark` for now (dark-only invariant). When a real Light mode
    /// lands, `system` becomes `nil` (follow the OS) and a new `.light` case is added —
    /// this method is the single switch-point.
    var resolvedColorScheme: ColorScheme {
        switch self {
        case .system, .dark: return .dark
        }
    }

    /// Round-trips an `@AppStorage` raw value, falling back to `.system` for unknown input.
    init(storage raw: String) {
        self = AppAppearance(rawValue: raw) ?? .system
    }
}
