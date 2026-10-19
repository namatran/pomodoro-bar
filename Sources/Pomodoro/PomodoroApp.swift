import Carbon
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private static let petVisibleKey = "petVisible"

    /// Shared by the menu bar and the pet. Lazy so it's built after `PomodoroApp.init` registers the default durations.
    lazy var timer = PomodoroTimer()
    let stopwatch = Stopwatch()
    let sessions = SessionStore()
    /// Remembered across launches, like the pet's position.
    @Published private(set) var isPetVisible = UserDefaults.standard.object(forKey: AppDelegate.petVisibleKey) as? Bool ?? true
    private var pet: PetController?
    private var hotKey: HotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        timer.onSessionSaved = { [sessions] in sessions.add($0) }
        pet = PetController(timer: timer, stopwatch: stopwatch, sessions: sessions, visible: isPetVisible)
        pet?.onHide = { [weak self] in self?.togglePet() }
        // claudepet already has ⌃⌥⌘P and cost has ⌃⌥⌘I.
        hotKey = HotKey(keyCode: kVK_ANSI_T, modifiers: controlKey | optionKey | cmdKey) { [weak self] in
            self?.togglePet()
        }
    }

    func togglePet() {
        isPetVisible.toggle()
        UserDefaults.standard.set(isPetVisible, forKey: Self.petVisibleKey)
        pet?.setVisible(isPetVisible)
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
            ContentView()
                .environmentObject(appDelegate.timer)
                .environmentObject(appDelegate)
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
        Text(timer.isAlarming ? "🔔" : "\(timer.phase.emoji) \(timer.remaining.clock)")
    }
}
