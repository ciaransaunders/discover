import SwiftUI
import SwiftData

/// Sidebar column of the `NavigationSplitView`.
///
/// Three sections: **Smart Feeds** (All / All Unread / Today / Starred), **Categories**
/// (one row per `CategoryModel`), and **Folders** (one row per `FolderModel`). Tapping a row sets
/// the shared `SidebarSelection` on the parent, which the detail column uses to build its `@Query`.
struct CategorySidebarView: View {

    @Binding var selection: SidebarSelection

    @Query(sort: \CategoryModel.priority) private var categories: [CategoryModel]
    @Query(sort: \FolderModel.priority) private var folders: [FolderModel]

    /// Every unread article, used for the live "All Unread" badge and read-feed computation.
    @Query(filter: #Predicate<ArticleModel> { !$0.isRead }) private var unreadArticles: [ArticleModel]

    var body: some View {
        List {
            // MARK: Smart Feeds
            Section("Smart Feeds") {
                smartRow(.all, label: "All News")
                smartRow(.allUnread, label: "All Unread", badge: unreadCount)
                smartRow(.today, label: "Today")
                smartRow(.starred, label: "Starred")
            }

            // MARK: Categories
            Section("Categories") {
                ForEach(categories) { category in
                    categoryRow(for: category)
                }
            }

            // MARK: Folders
            if !folders.isEmpty {
                Section("Folders") {
                    ForEach(folders) { folder in
                        folderRow(for: folder)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Discover")
    }

    // MARK: - Counts

    /// Live unread count for the "All Unread" badge.
    private var unreadCount: Int { unreadArticles.count }

    // MARK: - Row builders

    private func smartRow(_ target: SidebarSelection, label: String, badge: Int? = nil) -> some View {
        let isSelected = selection == target
        return Button {
            selection = target
        } label: {
            HStack(spacing: 8) {
                Image(systemName: target.systemImage)
                    .frame(width: 18)
                Text(label)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                Spacer()
                if let badge, badge > 0 {
                    Text("\(badge)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.secondary.opacity(0.18)))
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
        .listRowBackground(rowBackground(isSelected))
    }

    private func categoryRow(for category: CategoryModel) -> some View {
        let target = SidebarSelection.category(category.slug)
        let isSelected = selection == target
        return Button {
            selection = target
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
        .listRowBackground(rowBackground(isSelected))
    }

    private func folderRow(for folder: FolderModel) -> some View {
        // Selecting a folder carries its resolved member feed URLs so the article `@Query` can be
        // built without a ModelContext.
        let target = SidebarSelection.folder(slug: folder.slug, feedUrls: folder.feedUrls)
        // Selection identity is by slug only — match on the case, ignoring the carried URLs which
        // can change as membership is edited.
        let isSelected: Bool = {
            if case .folder(let slug, _) = selection { return slug == folder.slug }
            return false
        }()
        return Button {
            selection = target
        } label: {
            HStack(spacing: 8) {
                Image(systemName: folder.iconSystemName)
                    .frame(width: 18)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                Text(folder.name)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
        .listRowBackground(rowBackground(isSelected))
    }

    @ViewBuilder
    private func rowBackground(_ isSelected: Bool) -> some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(0.15))
        }
    }
}
