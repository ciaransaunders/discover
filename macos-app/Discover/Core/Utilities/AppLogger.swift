import Foundation
import OSLog

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.discover.app"

    /// Logs related to network requests, feed fetching, and image scraping.
    static let networking = Logger(subsystem: subsystem, category: "networking")

    /// Logs related to XML parsing, RSS/Atom structure, and thumbnail extraction.
    static let parsing = Logger(subsystem: subsystem, category: "parsing")

    /// Logs related to UI lifecycle, view model state changes, and user actions.
    static let ui = Logger(subsystem: subsystem, category: "ui")
    
    /// Logs related to SwiftData persistence and migrations.
    static let persistence = Logger(subsystem: subsystem, category: "persistence")
}
