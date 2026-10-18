import Foundation

extension Int {
    /// Seconds formatted as mm:ss.
    var clock: String { String(format: "%02d:%02d", self / 60, self % 60) }

    /// Seconds formatted as hh:mm:ss, like Google's timer.
    var longClock: String { String(format: "%02d:%02d:%02d", self / 3600, self / 60 % 60, self % 60) }
}

/// Google-timer style: Start/Pause and Reset. At zero it rings and holds; Reset saves the focus run and moves on.
@MainActor
final class PomodoroTimer: ObservableObject {
    /// Shorter focus runs are treated as accidental and not saved.
    static let minimumSessionSeconds = 60

    @Published private(set) var phase: Phase = .work
    @Published private(set) var remaining: Int = Phase.work.seconds
    @Published private(set) var isRunning = false
    /// The clock reached zero and is waiting for Reset.
    @Published private(set) var isFinished = false
    /// Started at least once since the last reset; the phase and length are locked until then.
    @Published private(set) var hasStarted = false
    @Published private(set) var completedToday = PomodoroLog.todayCount()
    @Published private(set) var isAlarming = false

    /// Called when Reset or Quit saves a focus run.
    var onSessionSaved: @MainActor (Session) -> Void = { _ in }

    private var workSessionsInCycle = 0
    private var ticker: Timer?
    private let alarm = Alarm()
    private var alarmCutoff: Task<Void, Never>?

    private var startedAt: Date?
    private var completedAt: Date?
    private var focusedSeconds = 0

    var canEdit: Bool { !hasStarted }

    init() {
        // Roll "Today" over at midnight even when nothing finishes.
        NotificationCenter.default.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.completedToday = PomodoroLog.todayCount() }
        }
    }

    func start() {
        stopAlarm()
        guard !isRunning, remaining > 0 else { return }
        if !hasStarted {
            hasStarted = true
            startedAt = Date()
        }
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

    /// Save the focus run, then load the next phase if the clock had finished, or restart this one.
    func reset() {
        stopAlarm()
        pause()
        saveRun()
        if isFinished { advance() }
        clearRun()
    }

    /// Choose the phase by hand, before the run has started.
    func select(_ phase: Phase) {
        guard canEdit else { return }
        self.phase = phase
        remaining = phase.seconds
    }

    /// A typed length for this run only; the next phase goes back to the settings.
    func setLength(_ seconds: Int) {
        guard canEdit, seconds > 0 else { return }
        remaining = seconds
    }

    /// Pick up changed durations when the clock hasn't started.
    func applySettings() {
        if canEdit { remaining = phase.seconds }
    }

    func stopAlarm() {
        guard isAlarming else { return }
        alarmCutoff?.cancel()
        alarmCutoff = nil
        alarm.stop()
        isAlarming = false
    }

    /// Save an unsaved focus run on Quit.
    func saveOnQuit() {
        saveRun()
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
        if phase == .work { focusedSeconds += 1 }
        if remaining <= 0 { finishPhase() }
    }

    /// The clock ran out: ring and hold at zero until Reset.
    private func finishPhase() {
        pause()
        isFinished = true
        if phase == .work { completedAt = Date() }
        Notifier.phaseEnded(phase, next: nextPhase)
        ringAlarm()
    }

    private func saveRun() {
        guard phase == .work, let startedAt, focusedSeconds >= Self.minimumSessionSeconds else { return }
        let session = Session(
            id: UUID(),
            startedAt: startedAt,
            completedAt: completedAt,
            endedAt: Date(),
            durationSeconds: focusedSeconds
        )
        PomodoroLog.recordCompleted()
        completedToday = PomodoroLog.todayCount()
        onSessionSaved(session)
        self.startedAt = nil
    }

    private func clearRun() {
        startedAt = nil
        completedAt = nil
        focusedSeconds = 0
        isFinished = false
        hasStarted = false
        remaining = phase.seconds
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
        let next = nextPhase
        if phase == .work { workSessionsInCycle += 1 }
        phase = next
    }
}
