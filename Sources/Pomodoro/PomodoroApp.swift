import SwiftUI

@main
struct PomodoroApp: App {
    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra("🍅 25:00") {
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
    }
}
