import Foundation
import SwiftUI

/// Counts up independently of the Pomodoro timer and is never saved.
@MainActor
final class Stopwatch: ObservableObject {
    @Published private(set) var elapsed = 0
    @Published private(set) var isRunning = false

    /// Time banked before the current run, so pausing keeps the partial second.
    private var banked: TimeInterval = 0
    private var runningSince: Date?
    private var ticker: Timer?

    func start() {
        guard !isRunning else { return }
        isRunning = true
        runningSince = Date()
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.update() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    func stop() {
        guard isRunning, let runningSince else { return }
        banked += Date().timeIntervalSince(runningSince)
        self.runningSince = nil
        isRunning = false
        ticker?.invalidate()
        ticker = nil
        update()
    }

    func reset() {
        stop()
        banked = 0
        elapsed = 0
    }

    private func update() {
        let total = banked + (runningSince.map { Date().timeIntervalSince($0) } ?? 0)
        let seconds = Int(total)
        if seconds != elapsed { elapsed = seconds }
    }
}

struct StopwatchTab: View {
    @ObservedObject var stopwatch: Stopwatch

    var body: some View {
        VStack(spacing: 10) {
            Text(stopwatch.elapsed.longClock)
                .font(.system(size: 34, weight: .semibold, design: .monospaced))
            HStack {
                Button(stopwatch.isRunning ? "Stop" : "Start") {
                    stopwatch.isRunning ? stopwatch.stop() : stopwatch.start()
                }
                .buttonStyle(.borderedProminent)
                Button("Reset") { stopwatch.reset() }
            }
        }
    }
}
