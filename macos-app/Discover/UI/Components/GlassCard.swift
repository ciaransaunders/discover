import SwiftUI

// MARK: - GlassCard ViewModifier

/// Applies Apple's Liquid Glass material to any view.
///
/// On macOS 26 / iOS 26 `.glassEffect(_:in:)` provides the system-managed
/// depth, lensing, and morphing automatically — no custom `.background()`
/// needed. Simply wrapping content with this modifier is sufficient.
struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .glassEffect(
                .regular,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
    }
}

// MARK: - Convenience extension

extension View {
    /// Wraps the view in the standard Liquid Glass card material.
    func glassCard(cornerRadius: CGFloat = 12) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
}
