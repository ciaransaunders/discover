import SwiftUI

/// The typeface families the in-app Reader offers (cluster A2).
///
/// Stored in `@AppStorage` as the raw `String`, so the cases are stable, lowercase
/// identifiers. Each case maps to a SwiftUI `Font.Design` used by the Reader's body
/// typography. `Sendable` so it can cross the `@MainActor` theme manager boundary safely.
enum ReaderFontFamily: String, CaseIterable, Identifiable, Sendable {
    case system
    case serif
    case mono

    var id: String { rawValue }

    /// Human-readable label for pickers.
    var label: String {
        switch self {
        case .system: return "System"
        case .serif:  return "Serif"
        case .mono:   return "Monospaced"
        }
    }

    /// The SwiftUI `Font.Design` this family resolves to.
    var design: Font.Design {
        switch self {
        case .system: return .default
        case .serif:  return .serif
        case .mono:   return .monospaced
        }
    }

    /// Round-trips an `@AppStorage` raw value, falling back to `.system` for unknown input.
    init(storage raw: String) {
        self = ReaderFontFamily(rawValue: raw) ?? .system
    }
}
