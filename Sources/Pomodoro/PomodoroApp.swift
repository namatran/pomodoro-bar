import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var pet: PetController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        pet = PetController()
    }
}

@main
struct PomodoroApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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
