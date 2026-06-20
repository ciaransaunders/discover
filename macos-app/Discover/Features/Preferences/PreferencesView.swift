import SwiftData
import SwiftUI

/// Preferences window (⌘,) for managing app-level settings.
/// Provides a tabbed interface for General settings and Feed management.
struct PreferencesView: View {

  @Environment(\.dismiss) private var dismiss
  // Cluster A2/A3 — the single owner of the reader.* / appearance keys (bind, don't re-declare).
  @Environment(ReaderThemeManager.self) private var theme

  @AppStorage("refreshIntervalMinutes") private var refreshInterval: Int = 30
  @AppStorage("maxArticleAgeDays") private var maxArticleAge: Int = 7
  @AppStorage("openLinksInBackground") private var openInBackground = false
  @AppStorage("markReadOnOpen") private var markReadOnOpen = true
  @AppStorage("notifyOnNewArticles") private var notifyOnNewArticles = false
  // Cluster A1 — card tap opens the in-app Reader by default.
  @AppStorage("tapOpensReader") private var tapOpensReader = true
  // Cluster C2 — hide read articles/feeds (view-layer only).
  @AppStorage("hideReadArticles") private var hideReadArticles = false
  @AppStorage("hideReadFeeds") private var hideReadFeeds = false

  var body: some View {
    @Bindable var theme = theme
    return NavigationStack {
      Form {
        // MARK: - Refresh
        Section("Refresh") {
          Picker("Auto-refresh interval", selection: $refreshInterval) {
            Text("15 minutes").tag(15)
            Text("30 minutes").tag(30)
            Text("1 hour").tag(60)
            Text("2 hours").tag(120)
            Text("Never").tag(0)
          }

          Picker("Keep articles for", selection: $maxArticleAge) {
            Text("Keep Forever").tag(0)
            Text("1 day").tag(1)
            Text("3 days").tag(3)
            Text("7 days").tag(7)
            Text("14 days").tag(14)
            Text("30 days").tag(30)
          }

          Toggle("Notify me about new articles", isOn: $notifyOnNewArticles)
          if notifyOnNewArticles {
            Text("Only shown if you have already allowed notifications for Discover in System Settings.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        // MARK: - Reading
        Section("Reading") {
          Toggle("Tap opens the in-app Reader", isOn: $tapOpensReader)
          Text("When off, tapping a card opens the article in your browser instead. The Reader is always available from the card's menu.")
            .font(.caption)
            .foregroundStyle(.secondary)
          Toggle("Mark articles as read when opened", isOn: $markReadOnOpen)
          Toggle("Open links in background", isOn: $openInBackground)
        }

        // MARK: - Appearance (cluster A2/A3)
        Section("Appearance") {
          Picker("App appearance", selection: $theme.appearance) {
            ForEach(AppAppearance.allCases) { mode in
              Text(mode.label).tag(mode)
            }
          }

          Picker("Reader font", selection: $theme.fontFamily) {
            ForEach(ReaderFontFamily.allCases) { family in
              Text(family.label).tag(family)
            }
          }

          Picker("Reader width", selection: $theme.lineWidth) {
            ForEach(ReaderLineWidth.allCases) { width in
              Text(width.label).tag(width)
            }
          }

          VStack(alignment: .leading, spacing: 6) {
            HStack {
              Text("Text size")
              Spacer()
              Text(fontScalePercent)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }
            Slider(
              value: $theme.fontScale,
              in: ReaderThemeManager.minFontScale...ReaderThemeManager.maxFontScale,
              step: 0.05
            )
          }

          appearancePreview
        }

        // MARK: - Organisation (cluster C2)
        Section("Organisation") {
          Toggle("Hide read articles", isOn: $hideReadArticles)
          Toggle("Hide feeds with no unread articles", isOn: $hideReadFeeds)
          Text("Hidden read items can be shown again any time from the toolbar or these toggles.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        // MARK: - Keyboard Shortcuts Reference
        Section("Keyboard Shortcuts") {
          shortcutRow("Refresh feeds", shortcut: "⌘R")
          shortcutRow("Force refresh all", shortcut: "⌘⇧R")
          shortcutRow("Open preferences", shortcut: "⌘,")
        }
      }
      .formStyle(.grouped)
      .navigationTitle("Preferences")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
    .frame(minWidth: 320, idealWidth: 480, minHeight: 400)
  }

  // MARK: - Appearance preview (cluster A2)

  /// Live mini-preview of how the Reader body renders with the current theme.
  private var appearancePreview: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Preview")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)

      VStack(alignment: .leading, spacing: 8) {
        Text("The quick brown fox")
          .font(theme.titleFont(baseSize: 18))
        Text("Jumps over the lazy dog and reads the morning news in comfortable, customisable type.")
          .font(theme.bodyFont(baseSize: 13))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(12)
      .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }
  }

  private var fontScalePercent: String {
    "\(Int((theme.fontScale * 100).rounded()))%"
  }

  // MARK: - Helpers

  private func shortcutRow(_ label: String, shortcut: String) -> some View {
    HStack {
      Text(label)
      Spacer()
      Text(shortcut)
        .font(.body.monospaced())
        .foregroundStyle(.secondary)
    }
  }
}
