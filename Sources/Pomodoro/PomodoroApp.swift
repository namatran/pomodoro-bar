import SwiftUI

@main
struct PomodoroApp: App {
    @StateObject private var timer = PomodoroTimer()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra("🍅 25:00") {
            ContentView().environmentObject(timer)
        }
        .menuBarExtraStyle(.window)
    }
}
