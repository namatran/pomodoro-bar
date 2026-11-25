import Foundation

/// One saved run, as kept in sessions.json (see docs/pet-design.md).
struct Session: Identifiable, Equatable, Codable {
    enum Kind: String, Codable {
        case focus, rest = "break"
    }

    let id: UUID
    let kind: Kind
    /// First start of the run.
    let startedAt: Date
    /// Focus: when the clock hit zero, nil if stopped early.
    /// Break: when the clock hit zero, or when Reset cut it short.
    let completedAt: Date?
    /// Focus only: when Reset or Quit saved it.
    let endedAt: Date?
    /// Time counted down, not counting pauses.
    let durationSeconds: Int

    /// Where the row's time range ends: the save for focus, the finish for a break.
    var end: Date { endedAt ?? completedAt ?? startedAt }

    /// The whole run from start to end, pauses included. This is the Length shown everywhere.
    var lengthSeconds: Int { Int(end.timeIntervalSince(startedAt)) }

    /// The same session with the edit sheet's values. A break ends at `end`. A focus session keeps whether it
    /// finished, and its clock still hits zero as long after the start as before, kept within the new times.
    func edited(kind: Kind, start: Date, end: Date, durationSeconds: Int) -> Session {
        switch kind {
        case .rest:
            return Session(id: id, kind: .rest, startedAt: start, completedAt: end, endedAt: nil, durationSeconds: durationSeconds)
        case .focus:
            let completed = completedAt.map { completedAt in
                let moved = start.addingTimeInterval(completedAt.timeIntervalSince(startedAt))
                return min(max(moved, start.addingTimeInterval(TimeInterval(durationSeconds))), end)
            }
            return Session(id: id, kind: .focus, startedAt: start, completedAt: completed, endedAt: end, durationSeconds: durationSeconds)
        }
    }

    /// Time spent paused, which the duration leaves out. Waiting at zero for Reset isn't a pause, and under a minute doesn't count.
    var pausedSeconds: Int {
        let paused = Int((completedAt ?? end).timeIntervalSince(startedAt)) - durationSeconds
        return paused >= 60 ? paused : 0
    }
}
