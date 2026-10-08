import SwiftUI

@main
struct PomodoroApp: App {
    @StateObject private var timer = PomodoroTimer()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            ContentView().environmentObject(timer)
        } label: {
            Text("\(timer.phase.emoji) \(timer.remaining.clock)")
        }
        .menuBarExtraStyle(.window)
    }
}
