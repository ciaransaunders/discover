import SwiftUI

extension Color {

    /// Initialise a `Color` from a CSS-style hex string.
    ///
    /// Accepted formats: `"#RGB"`, `"#RRGGBB"`, `"#AARRGGBB"`, and the same
    /// without the leading `#`.  Invalid strings resolve to opaque black.
    ///
    /// Example:
    /// ```swift
    /// Color(hex: "#8b5cf6")  // AI category purple
    /// Color(hex: "ef4444")   // Gaming category red
    /// ```
    init(hex: String) {
        let raw = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: raw).scanHexInt64(&int)

        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64

        switch raw.count {
        case 3:  // RGB (12-bit shorthand)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  // RRGGBB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  // AARRGGBB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red:     Double(r) / 255,
            green:   Double(g) / 255,
            blue:    Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
