import AppKit
import UserNotifications

enum Notifier {
    /// Notifications need an app bundle; a bare `swift run` binary has no bundle identifier.
    private static var canNotify: Bool { Bundle.main.bundleIdentifier != nil }

    static func requestAuthorization() {
        guard canNotify else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func phaseEnded(_ phase: Phase, next: Phase) {
        NSSound(named: "Glass")?.play()
        guard canNotify else { return }
        let content = UNMutableNotificationContent()
        content.title = "\(phase.label) finished"
        content.body = "Up next: \(next.label)"
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
