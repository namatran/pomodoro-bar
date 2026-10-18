import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Shared by the menu bar and the pet. Lazy so it's built after `PomodoroApp.init` registers the default durations.
    lazy var timer = PomodoroTimer()
    let stopwatch = Stopwatch()
    let today = MockToday()
    private var pet: PetController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        timer.onSessionSaved = { [today] in today.add($0) }
        pet = PetController(timer: timer, stopwatch: stopwatch, today: today)
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer.saveOnQuit()
    }
}

@main
struct PomodoroApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        Settings.registerDefaults()
        Notifier.requestAuthorization()
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            ContentView().environmentObject(appDelegate.timer)
        } label: {
            MenuBarLabel(timer: appDelegate.timer)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Its own view so the title keeps observing the timer now that the delegate owns it.
struct MenuBarLabel: View {
    @ObservedObject var timer: PomodoroTimer

    var body: some View {
        Text(timer.isAlarming ? "🔔 Time's up" : "\(timer.phase.emoji) \(timer.remaining.clock)")
    }
}
