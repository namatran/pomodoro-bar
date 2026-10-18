import Foundation

enum Settings {
    static let workKey = "workMinutes"
    /// Keeps the old short-break key so an existing setting carries over.
    static let breakKey = "shortBreakMinutes"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            workKey: 25,
            breakKey: 5,
        ])
    }
}

enum Phase: CaseIterable {
    case work, rest

    var minutesKey: String {
        switch self {
        case .work: return Settings.workKey
        case .rest: return Settings.breakKey
        }
    }

    var seconds: Int { UserDefaults.standard.integer(forKey: minutesKey) * 60 }

    var other: Phase { self == .work ? .rest : .work }

    var emoji: String {
        switch self {
        case .work: return "🍅"
        case .rest: return "☕️"
        }
    }

    var label: String {
        switch self {
        case .work: return "Focus"
        case .rest: return "Break"
        }
    }
}
