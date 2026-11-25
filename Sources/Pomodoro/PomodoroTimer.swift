import Foundation

extension Int {
    /// Seconds formatted as mm:ss.
    var clock: String { String(format: "%02d:%02d", self / 60, self % 60) }
}

/// Google-timer style: Start/Pause and Reset, in Focus or Break mode. At zero it rings and holds;
/// Reset saves the run and switches mode. Focus can keep going past zero, counting up until Reset.
@MainActor
final class PomodoroTimer: ObservableObject {
    /// Shorter runs may be accidental, so saving one asks first.
    static let shortRunSeconds = 30

    @Published private(set) var phase: Phase = .work
    @Published private(set) var remaining: Int = Phase.work.seconds
    @Published private(set) var isRunning = false
    /// The clock reached zero and is waiting for Reset.
    @Published private(set) var isFinished = false
    /// Started at least once since the last reset; the mode is locked until then.
    @Published private(set) var hasStarted = false
    @Published private(set) var isAlarming = false
    /// A focus run kept going past zero, counting up.
    @Published private(set) var isOvertime = false
    /// Seconds counted past zero.
    @Published private(set) var overtime = 0

    /// Called when Reset, Quit or a typed new time saves a run.
    var onSessionSaved: @MainActor (Session) -> Void = { _ in }
    /// Asked before Reset or a typed new time saves a short run, with its seconds counted. True saves it.
    var confirmShortRun: @MainActor (Int) -> Bool = { _ in true }

    private var ticker: Timer?
    private let alarm = Alarm()
    private var alarmCutoff: Task<Void, Never>?

    private var startedAt: Date?
    private var completedAt: Date?
    private var countedSeconds = 0
    private var pauses: [Session.Pause] = []
    /// When the open pause began, if the run is paused.
    private var pausedAt: Date?

    /// Fresh or just reset: the mode can change and settings apply.
    var isFresh: Bool { !hasStarted }

    /// The clock reached zero and Reset hasn't saved the run yet.
    var hasUnsavedRun: Bool { isFinished }

    /// Focus held at zero, where Start keeps it going.
    var canKeepGoing: Bool { isFinished && phase == .work }

    /// mm:ss counting down, or +mm:ss past zero.
    var clockText: String { isOvertime ? "+\(overtime.clock)" : remaining.clock }

    /// A new time can be typed whenever the clock isn't running.
    var canType: Bool { !isRunning }

    /// Start or resume. At zero in focus, keep going: the clock counts up and Reset saves it all.
    func start() {
        stopAlarm()
        guard !isRunning else { return }
        if canKeepGoing {
            isFinished = false
            isOvertime = true
        }
        guard remaining > 0 || isOvertime else { return }
        if !hasStarted {
            hasStarted = true
            startedAt = Date()
        }
        closePause()
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
        guard isRunning else { return }
        stopTicking()
        pausedAt = Date()
    }

    private func stopTicking() {
        isRunning = false
        ticker?.invalidate()
        ticker = nil
    }

    /// End the open pause now, keeping it if it lasted a minute or more.
    private func closePause() {
        guard let pausedAt else { return }
        let pause = Session.Pause(start: pausedAt, end: Date())
        if pause.seconds >= 60 { pauses.append(pause) }
        self.pausedAt = nil
    }

    /// Save the run, then switch mode if the clock had finished, or restart this one.
    func reset() {
        stopAlarm()
        stopTicking()
        saveRun()
        if isFinished || isOvertime { phase = phase.other }
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

    /// Save an unsaved run on Quit, short or not: a prompt would hold up quitting.
    func saveOnQuit() {
        saveRun(asking: false)
    }

    private func tick() {
        guard isRunning else { return }
        countedSeconds += 1
        if isOvertime {
            overtime += 1
            return
        }
        remaining -= 1
        if remaining <= 0 { finishPhase() }
    }

    /// The clock ran out: ring and hold at zero until Reset.
    private func finishPhase() {
        stopTicking()
        isFinished = true
        completedAt = Date()
        Notifier.phaseEnded(phase, next: phase.other)
        ringAlarm()
    }

    private func saveRun(asking: Bool = true) {
        guard let startedAt else { return }
        if asking && countedSeconds < Self.shortRunSeconds && !confirmShortRun(countedSeconds) { return }
        // Paused when Reset or Quit came: the pause runs to the save.
        closePause()
        let now = Date()
        let session: Session
        switch phase {
        case .work:
            // Held at zero and not kept going, it ends at zero, so a missed alarm adds no time.
            session = Session(id: UUID(), kind: .focus, startedAt: startedAt, completedAt: completedAt,
                              endedAt: isFinished ? completedAt : now, durationSeconds: countedSeconds, pauses: pauses)
        case .rest:
            // A break ends when its clock did, or when Reset cut it short; it has no separate save time.
            session = Session(id: UUID(), kind: .rest, startedAt: startedAt, completedAt: completedAt ?? now,
                              endedAt: nil, durationSeconds: countedSeconds, pauses: pauses)
        }
        onSessionSaved(session)
        self.startedAt = nil
    }

    private func clearRun() {
        startedAt = nil
        completedAt = nil
        countedSeconds = 0
        pauses = []
        pausedAt = nil
        isFinished = false
        isOvertime = false
        overtime = 0
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
