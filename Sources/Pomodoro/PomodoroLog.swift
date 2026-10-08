import Foundation

/// Completed focus sessions per calendar day, persisted in UserDefaults.
enum PomodoroLog {
    private static let key = "completedByDay"

    private static var today: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private static var counts: [String: Int] {
        UserDefaults.standard.dictionary(forKey: key) as? [String: Int] ?? [:]
    }

    static func todayCount() -> Int { counts[today] ?? 0 }

    static func recordCompleted() {
        var updated = counts
        updated[today, default: 0] += 1
        UserDefaults.standard.set(updated, forKey: key)
    }
}
