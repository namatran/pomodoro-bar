import Foundation

extension Int {
    /// Seconds formatted as mm:ss.
    var clock: String { String(format: "%02d:%02d", self / 60, self % 60) }
}

@MainActor
final class PomodoroTimer: ObservableObject {
    @Published private(set) var phase: Phase = .work
    @Published private(set) var remaining: Int = Phase.work.seconds
    @Published private(set) var isRunning = false

    private var workSessionsInCycle = 0
    private var ticker: Timer?

    func start() {
        guard !isRunning, remaining > 0 else { return }
        isRunning = true
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    func pause() {
        isRunning = false
        ticker?.invalidate()
        ticker = nil
    }

    func reset() {
        pause()
        remaining = phase.seconds
    }

    /// Jump to the next phase without finishing the current one.
    func skip() {
        advance()
    }

    private var nextPhase: Phase {
        switch phase {
        case .work: return (workSessionsInCycle + 1) % 4 == 0 ? .longBreak : .shortBreak
        case .shortBreak, .longBreak: return .work
        }
    }

    private func tick() {
        guard isRunning else { return }
        remaining -= 1
        if remaining <= 0 { advance() }
    }

    private func advance() {
        pause()
        let next = nextPhase
        if phase == .work { workSessionsInCycle += 1 }
        phase = next
        remaining = next.seconds
    }
}
