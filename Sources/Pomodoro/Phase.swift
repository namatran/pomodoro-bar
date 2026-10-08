import Foundation

enum Settings {
    static let workKey = "workMinutes"
    static let shortBreakKey = "shortBreakMinutes"
    static let longBreakKey = "longBreakMinutes"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            workKey: 25,
            shortBreakKey: 5,
            longBreakKey: 15,
        ])
    }
}

enum Phase {
    case work, shortBreak, longBreak

    var minutesKey: String {
        switch self {
        case .work: return Settings.workKey
        case .shortBreak: return Settings.shortBreakKey
        case .longBreak: return Settings.longBreakKey
        }
    }

    var seconds: Int { UserDefaults.standard.integer(forKey: minutesKey) * 60 }

    var emoji: String {
        switch self {
        case .work: return "🍅"
        case .shortBreak: return "☕️"
        case .longBreak: return "🌴"
        }
    }

    var label: String {
        switch self {
        case .work: return "Focus"
        case .shortBreak: return "Short break"
        case .longBreak: return "Long break"
        }
    }
}
