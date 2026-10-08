import SwiftUI

@main
struct PomodoroApp: App {
    @StateObject private var timer = PomodoroTimer()

    init() {
        Settings.registerDefaults()
        Notifier.requestAuthorization()
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            ContentView().environmentObject(timer)
        } label: {
            Text(timer.isAlarming ? "🔔 Time's up" : "\(timer.phase.emoji) \(timer.remaining.clock)")
        }
        .menuBarExtraStyle(.window)
    }
}
