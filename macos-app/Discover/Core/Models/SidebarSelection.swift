import Foundation

/// The single navigation vocabulary for what the sidebar has selected.
///
/// This is **not** a `@Model` — it is a transient, `Sendable` value type shared by the sidebar,
/// `ContentView`, and `ArticleListView` (which builds its `@Query` predicate from it). Both the
/// organisation cluster (folders/starred) and the smart-feeds cluster (all-unread/today) extend
/// the same enum so there is one selection type, not two parallel ones.
///
/// It is `Codable` (window restoration) and round-trips losslessly through a `String` `rawValue`
/// (used for the iOS `NavigationSplitView` String binding and `@AppStorage`).
enum SidebarSelection: Hashable, Sendable, Codable {
    /// All articles across every feed.
    case all
    /// Smart feed: every unread article.
    case allUnread
    /// Smart feed: articles published today (device-local calendar day).
    case today
    /// Smart feed: starred articles.
    case starred
    /// A single category, by slug.
    case category(String)
    /// A folder, by slug, carrying its resolved member feed URLs so the article query can be
    /// built without a `ModelContext` (the `@Query` is constructed in `ArticleListView.init`).
    case folder(slug: String, feedUrls: [String])

    /// The default selection on launch.
    static let `default` = SidebarSelection.all
}

// MARK: - Display

extension SidebarSelection {
    /// Navigation-bar / window title for this selection.
    /// For `.category`/`.folder` this is a capitalised slug fallback; callers with access to
    /// `CategoryModel`/`FolderModel` should prefer the stored label/name.
    var title: String {
        switch self {
        case .all:                return "All News"
        case .allUnread:          return "All Unread"
        case .today:              return "Today"
        case .starred:            return "Starred"
        case .category(let slug): return slug.capitalized
        case .folder(let slug, _): return slug.capitalized
        }
    }

    /// SF Symbol used for the sidebar row.
    var systemImage: String {
        switch self {
        case .all:        return "tray.full"
        case .allUnread:  return "largecircle.fill.circle"
        case .today:      return "sun.max"
        case .starred:    return "star.fill"
        case .category:   return "number"
        case .folder:     return "folder.fill"
        }
    }

    /// `true` for the synthetic "smart feed" rows (not a real category/folder).
    var isSmartFeed: Bool {
        switch self {
        case .allUnread, .today, .starred: return true
        default: return false
        }
    }
}

// MARK: - Restoration resolution (cluster F2)

extension SidebarSelection {
    /// Resolves a (possibly stale) restored selection against the categories/folders that currently
    /// exist, falling back to `.all` when the referenced category or folder has since been deleted.
    ///
    /// Multi-window state restoration (`WindowGroup(for:)`) can hand back a `.category`/`.folder`
    /// selection whose slug no longer exists; opening such a window would otherwise show an empty
    /// list with a stale title. Pure (takes the existing slug sets as parameters) so it is testable
    /// without SwiftData.
    func resolved(
        availableCategorySlugs: Set<String>,
        availableFolderSlugs: Set<String>
    ) -> SidebarSelection {
        switch self {
        case .category(let slug):
            return availableCategorySlugs.contains(slug) ? self : .all
        case .folder(let slug, _):
            return availableFolderSlugs.contains(slug) ? self : .all
        case .all, .allUnread, .today, .starred:
            return self
        }
    }
}

// MARK: - String round-trip (lossless, manual)

// A compact, self-contained string encoding so the type can drive `@AppStorage` and the iOS
// `NavigationSplitView` String binding. Fields are newline-separated; the first field is the kind.
// Feed URLs and category/folder slugs never contain newlines, so this is lossless.
//
// IMPORTANT: `rawValue` must NOT route through `Codable`/`JSONEncoder`. Because this type is both
// `Codable` and `RawRepresentable<String>`, the standard library satisfies `Encodable` *via*
// `rawValue` — so encoding through `Codable` here would recurse infinitely. Keep this manual.
extension SidebarSelection: RawRepresentable {
    private static let separator = "\n"

    var rawValue: String {
        switch self {
        case .all:                 return "all"
        case .allUnread:           return "allUnread"
        case .today:               return "today"
        case .starred:             return "starred"
        case .category(let slug):  return (["category", slug]).joined(separator: Self.separator)
        case .folder(let slug, let urls):
            return (["folder", slug] + urls).joined(separator: Self.separator)
        }
    }

    init?(rawValue: String) {
        let parts = rawValue.components(separatedBy: Self.separator)
        guard let kind = parts.first else { return nil }
        switch kind {
        case "all":       self = .all
        case "allUnread": self = .allUnread
        case "today":     self = .today
        case "starred":   self = .starred
        case "category":
            guard parts.count >= 2 else { return nil }
            self = .category(parts[1])
        case "folder":
            guard parts.count >= 2 else { return nil }
            self = .folder(slug: parts[1], feedUrls: Array(parts.dropFirst(2)))
        default:
            return nil
        }
    }
}
