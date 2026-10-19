import Foundation
import SwiftUI

/// Counts up independently of the Pomodoro timer and is never saved.
@MainActor
final class Stopwatch: ObservableObject {
    @Published private(set) var isRunning = false

    /// Time banked before the current run, so pausing keeps the partial second.
    @Published private var banked: TimeInterval = 0
    private var runningSince: Date?

    func start() {
        guard !isRunning else { return }
        isRunning = true
        runningSince = Date()
    }

    func stop() {
        guard isRunning, let runningSince else { return }
        banked += Date().timeIntervalSince(runningSince)
        self.runningSince = nil
        isRunning = false
    }

    func reset() {
        stop()
        banked = 0
    }

    func elapsed(at date: Date) -> TimeInterval {
        banked + (runningSince.map { date.timeIntervalSince($0) } ?? 0)
    }
}

struct StopwatchTab: View {
    @ObservedObject var stopwatch: Stopwatch

    var body: some View {
        VStack(spacing: 10) {
            // Redraws every frame while running, so the hundredths tick smoothly.
            TimelineView(.animation(paused: !stopwatch.isRunning)) { context in
                Text(Self.format(stopwatch.elapsed(at: context.date)))
                    .font(.system(size: 34, weight: .semibold, design: .monospaced))
            }
            HStack {
                Button(stopwatch.isRunning ? "Stop" : "Start") {
                    stopwatch.isRunning ? stopwatch.stop() : stopwatch.start()
                }
                .buttonStyle(.borderedProminent)
                Button("Reset") { stopwatch.reset() }
            }
        }
    }

    /// Like Google's stopwatch: `3.25`, `1:05.25`, `1:00:05.25`. Hours keep counting past 99.
    private static func format(_ elapsed: TimeInterval) -> String {
        let hundredths = Int(elapsed * 100)
        let h = hundredths / 360_000, m = hundredths / 6000 % 60, s = hundredths / 100 % 60, cs = hundredths % 100
        if h > 0 { return String(format: "%d:%02d:%02d.%02d", h, m, s, cs) }
        if m > 0 { return String(format: "%d:%02d.%02d", m, s, cs) }
        return String(format: "%d.%02d", s, cs)
    }
}
