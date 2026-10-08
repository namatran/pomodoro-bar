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
    @Published private(set) var completedToday = PomodoroLog.todayCount()

    private var workSessionsInCycle = 0
    private var ticker: Timer?

    init() {
        // Roll "Today" over at midnight even when nothing finishes.
        NotificationCenter.default.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.completedToday = PomodoroLog.todayCount() }
        }
    }

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

    /// Pick up changed durations when the clock is idle.
    func applySettings() {
        if !isRunning { remaining = phase.seconds }
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
        if remaining <= 0 { finishPhase() }
    }

    /// The clock ran out naturally (as opposed to skipping).
    private func finishPhase() {
        if phase == .work {
            PomodoroLog.recordCompleted()
            completedToday = PomodoroLog.todayCount()
        }
        Notifier.phaseEnded(phase, next: nextPhase)
        advance()
    }

    private func advance() {
        pause()
        let next = nextPhase
        if phase == .work { workSessionsInCycle += 1 }
        phase = next
        remaining = next.seconds
    }
}
