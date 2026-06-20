import Foundation
import CoreGraphics

/// The user-selectable grid density for the article list (cluster F1 view options).
///
/// A view option (not schema): persisted in `@AppStorage` by its stable `rawValue` and applied by
/// driving the adaptive `GridItem` minimum width — a smaller minimum packs more (narrower) columns
/// in, a larger minimum yields fewer (wider) columns. `.comfortable` reproduces the existing layout
/// (280 pt minimum), so the default leaves the grid visually unchanged.
///
/// `Sendable`/`Codable`; raw values are stable identifiers (persisted) — append new cases, do not
/// renumber.
enum ArticleListDensity: String, CaseIterable, Identifiable, Sendable, Codable {
    /// Fewer, wider columns.
    case spacious = "spacious"
    /// The app default — matches the pre-F1 layout (280 pt adaptive minimum).
    case comfortable = "comfortable"
    /// More, narrower columns.
    case compact = "compact"

    var id: String { rawValue }

    /// The default density (matches the historical 280 pt adaptive grid).
    static let `default` = ArticleListDensity.comfortable

    /// Human-readable menu label.
    var label: String {
        switch self {
        case .spacious:    return "Spacious"
        case .comfortable: return "Comfortable"
        case .compact:     return "Compact"
        }
    }

    /// SF Symbol shown beside the menu item.
    var systemImage: String {
        switch self {
        case .spacious:    return "rectangle"
        case .comfortable: return "rectangle.grid.1x2"
        case .compact:     return "square.grid.3x3"
        }
    }

    /// Minimum column width fed to the adaptive `GridItem`. Smaller → more columns.
    var minColumnWidth: CGFloat {
        switch self {
        case .spacious:    return 360
        case .comfortable: return 280
        case .compact:     return 220
        }
    }

    /// Maximum column width fed to the adaptive `GridItem`.
    var maxColumnWidth: CGFloat {
        switch self {
        case .spacious:    return 480
        case .comfortable: return 380
        case .compact:     return 300
        }
    }
}
