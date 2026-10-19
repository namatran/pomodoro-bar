import SwiftUI

struct ContentView: View {
    @EnvironmentObject var timer: PomodoroTimer
    @EnvironmentObject var app: AppDelegate
    @AppStorage(Settings.workKey) private var workMinutes = 25
    @AppStorage(Settings.breakKey) private var breakMinutes = 5

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button(app.isPetVisible ? "Hide pet" : "Show pet") { app.togglePet() }
                Text("⌃⌥⌘T")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Divider()
            if timer.isAlarming {
                Button("Stop alarm") { timer.stopAlarm() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            Text(timer.phase.label)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(timer.remaining.clock)
                .font(.system(size: 40, weight: .semibold, design: .monospaced))
            HStack {
                Button(timer.isRunning ? "Pause" : "Start") {
                    timer.isRunning ? timer.pause() : timer.start()
                }
                Button("Reset") { timer.reset() }
            }
            Text("Today: \(timer.completedToday) 🍅")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Stepper("Focus: \(workMinutes) min", value: $workMinutes, in: 1...90)
                Stepper("Break: \(breakMinutes) min", value: $breakMinutes, in: 1...60)
            }
            .onChange(of: workMinutes) { timer.applySettings() }
            .onChange(of: breakMinutes) { timer.applySettings() }
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .padding()
        .frame(width: 240)
    }
}
