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
    @Published private(set) var isAlarming = false

    private var workSessionsInCycle = 0
    private var ticker: Timer?
    private let alarm = Alarm()
    private var alarmCutoff: Task<Void, Never>?

    init() {
        // Roll "Today" over at midnight even when nothing finishes.
        NotificationCenter.default.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.completedToday = PomodoroLog.todayCount() }
        }
    }

    func start() {
        stopAlarm()
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
        stopAlarm()
        pause()
        remaining = phase.seconds
    }

    /// Pick up changed durations when the clock is idle.
    func applySettings() {
        if !isRunning { remaining = phase.seconds }
    }

    /// Jump to the next phase without finishing the current one.
    func skip() {
        stopAlarm()
        advance()
    }

    func stopAlarm() {
        guard isAlarming else { return }
        alarmCutoff?.cancel()
        alarmCutoff = nil
        alarm.stop()
        isAlarming = false
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
        ringAlarm()
    }

    private func ringAlarm() {
        alarm.start()
        isAlarming = true
        // Don't ring forever if nobody is at the desk.
        alarmCutoff = Task { [weak self] in
            try? await Task.sleep(for: .seconds(60))
            guard !Task.isCancelled else { return }
            self?.stopAlarm()
        }
    }

    private func advance() {
        pause()
        let next = nextPhase
        if phase == .work { workSessionsInCycle += 1 }
        phase = next
        remaining = next.seconds
    }
}
