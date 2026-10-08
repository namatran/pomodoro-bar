import Foundation

extension Int {
    /// Seconds formatted as mm:ss.
    var clock: String { String(format: "%02d:%02d", self / 60, self % 60) }
}

@MainActor
final class PomodoroTimer: ObservableObject {
    @Published private(set) var remaining: Int
    @Published private(set) var isRunning = false

    private let duration: Int
    private var ticker: Timer?

    init(duration: Int = 25 * 60) {
        self.duration = duration
        self.remaining = duration
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
        remaining = duration
    }

    private func tick() {
        guard isRunning else { return }
        remaining -= 1
        if remaining <= 0 { pause() }
    }
}
