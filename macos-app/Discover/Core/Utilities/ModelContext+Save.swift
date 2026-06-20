import OSLog
import SwiftData

extension ModelContext {
    /// Attempts to save and logs failures to Console (keeps UI code lightweight).
    func saveOrLog(_ reason: String) {
        do { try save() }
        catch {
            Logger.persistence.error("SwiftData save failed (\(reason, privacy: .public)): \(error.localizedDescription, privacy: .public)")
        }
    }
}
