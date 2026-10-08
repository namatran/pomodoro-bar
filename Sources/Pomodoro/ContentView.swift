import SwiftUI

struct ContentView: View {
    @EnvironmentObject var timer: PomodoroTimer

    var body: some View {
        VStack(spacing: 12) {
            Text(timer.remaining.clock)
                .font(.system(size: 40, weight: .semibold, design: .monospaced))
            HStack {
                Button(timer.isRunning ? "Pause" : "Start") {
                    timer.isRunning ? timer.pause() : timer.start()
                }
                Button("Reset") { timer.reset() }
            }
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .padding()
        .frame(width: 220)
    }
}
