import SwiftUI

struct ContentView: View {
    @EnvironmentObject var timer: PomodoroTimer
    @AppStorage(Settings.workKey) private var workMinutes = 25
    @AppStorage(Settings.shortBreakKey) private var shortBreakMinutes = 5
    @AppStorage(Settings.longBreakKey) private var longBreakMinutes = 15

    var body: some View {
        VStack(spacing: 12) {
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
                Button("Skip") { timer.skip() }
            }
            Text("Today: \(timer.completedToday) 🍅")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Stepper("Focus: \(workMinutes) min", value: $workMinutes, in: 1...90)
                Stepper("Short break: \(shortBreakMinutes) min", value: $shortBreakMinutes, in: 1...30)
                Stepper("Long break: \(longBreakMinutes) min", value: $longBreakMinutes, in: 1...60)
            }
            .onChange(of: workMinutes) { timer.applySettings() }
            .onChange(of: shortBreakMinutes) { timer.applySettings() }
            .onChange(of: longBreakMinutes) { timer.applySettings() }
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .padding()
        .frame(width: 240)
    }
}
