import SwiftData
import SwiftUI

/// Preferences window (⌘,) for managing app-level settings.
/// Provides a tabbed interface for General settings and Feed management.
struct PreferencesView: View {

  @Environment(\.dismiss) private var dismiss

  @AppStorage("refreshIntervalMinutes") private var refreshInterval: Int = 30
  @AppStorage("maxArticleAgeDays") private var maxArticleAge: Int = 7
  @AppStorage("openLinksInBackground") private var openInBackground = false
  @AppStorage("markReadOnOpen") private var markReadOnOpen = true
  @AppStorage("notifyOnNewArticles") private var notifyOnNewArticles = false

  var body: some View {
    NavigationStack {
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
          Toggle("Mark articles as read when opened", isOn: $markReadOnOpen)
          Toggle("Open links in background", isOn: $openInBackground)
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
