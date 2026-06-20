import SwiftUI

/// Displays a human-readable relative timestamp ("2 hours ago", "Just now", etc.)
/// that updates automatically every minute via a `TimelineView`.
struct TimeAgoText: View {
    let date: Date

    var body: some View {
        TimelineView(.periodic(from: date, by: 60)) { _ in
            Text(relativeString(from: date))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Formatting

    private func relativeString(from date: Date) -> String {
        let seconds = Int(Date.now.timeIntervalSince(date))
        guard seconds >= 0 else { return "Just now" }

        switch seconds {
        case 0 ..< 60:        return "Just now"
        case 60 ..< 3_600:
            let m = seconds / 60
            return "\(m) \(m == 1 ? "min" : "mins") ago"
        case 3_600 ..< 86_400:
            let h = seconds / 3_600
            return "\(h) \(h == 1 ? "hour" : "hours") ago"
        case 86_400 ..< 604_800:
            let d = seconds / 86_400
            return "\(d) \(d == 1 ? "day" : "days") ago"
        default:
            return date.formatted(date: .abbreviated, time: .omitted)
        }
    }
}
