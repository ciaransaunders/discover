import SwiftUI
import SwiftData

/// Sidebar column of the `NavigationSplitView`.
///
/// Shows an "All" row at the top, then one row per `CategoryModel` sorted by
/// priority.  Tapping a row sets `selectedCategory` on the parent, which the
/// detail column uses to filter articles.
struct CategorySidebarView: View {

    @Binding var selectedCategory: String?
    @Query(sort: \CategoryModel.priority) private var categories: [CategoryModel]

    var body: some View {
        List {
            allRow
            Divider()
            ForEach(categories) { category in
                categoryRow(for: category)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Discover")
    }

    // MARK: - Row builders

    private var allRow: some View {
        Button {
            selectedCategory = nil
        } label: {
            Label("All", systemImage: "square.grid.2x2.fill")
                .fontWeight(selectedCategory == nil ? .semibold : .regular)
                .foregroundStyle(selectedCategory == nil ? .primary : .secondary)
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
        .listRowBackground(
            selectedCategory == nil
                ? RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(0.15))
                : nil
        )
    }

    private func categoryRow(for category: CategoryModel) -> some View {
        let isSelected = selectedCategory == category.slug
        return Button {
            selectedCategory = category.slug
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(hex: category.colorHex))
                    .frame(width: 8, height: 8)
                Text(category.label)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
        .listRowBackground(
            isSelected
                ? RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(0.15))
                : nil
        )
    }
}
