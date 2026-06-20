import SwiftUI

/// A compact pill badge that displays a category label with its brand colour.
struct CategoryBadge: View {
    let label:    String
    let colorHex: String

    var body: some View {
        Text(label.capitalized)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(Color(hex: colorHex))
            )
    }
}

#Preview {
    HStack {
        CategoryBadge(label: "AI",      colorHex: "#8B5CF6")
        CategoryBadge(label: "Gaming",  colorHex: "#EF4444")
        CategoryBadge(label: "Finance", colorHex: "#22C55E")
    }
    .padding()
}
