import Foundation

extension Int {
    /// Seconds formatted as mm:ss.
    var clock: String { String(format: "%02d:%02d", self / 60, self % 60) }
}

/// Google-timer style: Start/Pause and Reset, in Focus or Break mode. At zero it rings and holds;
/// Reset saves the run and switches mode.
@MainActor
final class PomodoroTimer: ObservableObject {
    /// Shorter runs are treated as accidental and not saved.
    static let minimumSessionSeconds = 60

    @Published private(set) var phase: Phase = .work
    @Published private(set) var remaining: Int = Phase.work.seconds
    @Published private(set) var isRunning = false
    /// The clock reached zero and is waiting for Reset.
    @Published private(set) var isFinished = false
    /// Started at least once since the last reset; the mode is locked until then.
    @Published private(set) var hasStarted = false
    @Published private(set) var isAlarming = false

    /// Called when Reset, Quit or a typed new time saves a run.
    var onSessionSaved: @MainActor (Session) -> Void = { _ in }

    private var ticker: Timer?
    private let alarm = Alarm()
    private var alarmCutoff: Task<Void, Never>?

    private var startedAt: Date?
    private var completedAt: Date?
    private var countedSeconds = 0

    /// Fresh or just reset: the mode can change and settings apply.
    var isFresh: Bool { !hasStarted }

    /// A new time can be typed whenever the clock isn't running.
    var canType: Bool { !isRunning }

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

    /// Start a typed time. A run already under way (paused or finished) ends and is saved first.
    func start(seconds: Int) {
        guard canType, seconds > 0 else { return }
        if hasStarted {
            stopAlarm()
            saveRun()
            clearRun()
        }
        remaining = seconds
        start()
    }

    func pause() {
        isRunning = false
        ticker?.invalidate()
        ticker = nil
    }

    /// Save the run, then switch mode if the clock had finished, or restart this one.
    func reset() {
        stopAlarm()
        pause()
        saveRun()
        if isFinished { phase = phase.other }
        clearRun()
    }

    /// Choose Focus or Break by hand, before the run has started.
    func select(_ phase: Phase) {
        guard isFresh else { return }
        self.phase = phase
        remaining = phase.seconds
    }

    /// Pick up changed durations when the clock hasn't started.
    func applySettings() {
        if isFresh { remaining = phase.seconds }
    }

    func stopAlarm() {
        guard isAlarming else { return }
        alarmCutoff?.cancel()
        alarmCutoff = nil
        alarm.stop()
        isAlarming = false
    }

    /// Save an unsaved run on Quit.
    func saveOnQuit() {
        saveRun()
    }

    private func tick() {
        guard isRunning else { return }
        remaining -= 1
        countedSeconds += 1
        if remaining <= 0 { finishPhase() }
    }

    /// The clock ran out: ring and hold at zero until Reset.
    private func finishPhase() {
        pause()
        isFinished = true
        completedAt = Date()
        Notifier.phaseEnded(phase, next: phase.other)
        ringAlarm()
    }

    private func saveRun() {
        guard let startedAt, countedSeconds >= Self.minimumSessionSeconds else { return }
        let now = Date()
        let session: Session
        switch phase {
        case .work:
            session = Session(id: UUID(), kind: .focus, startedAt: startedAt, completedAt: completedAt,
                              endedAt: now, durationSeconds: countedSeconds)
            PomodoroLog.recordCompleted()
        case .rest:
            // A break ends when its clock did, or when Reset cut it short; it has no separate save time.
            session = Session(id: UUID(), kind: .rest, startedAt: startedAt, completedAt: completedAt ?? now,
                              endedAt: nil, durationSeconds: countedSeconds)
        }
        onSessionSaved(session)
        self.startedAt = nil
    }

    private func clearRun() {
        startedAt = nil
        completedAt = nil
        countedSeconds = 0
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
}
