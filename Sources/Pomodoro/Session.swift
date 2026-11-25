import Foundation

/// One saved run, as kept in sessions.json (see docs/pet-design.md).
struct Session: Identifiable, Equatable, Codable {
    enum Kind: String, Codable {
        case focus, rest = "break"
    }

    /// One stretch with the clock paused.
    struct Pause: Codable, Equatable {
        let start: Date
        let end: Date
        var seconds: Int { Int(end.timeIntervalSince(start)) }
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
    /// Each pause of a minute or more, oldest first. Nil for sessions saved before pauses were recorded.
    let pauses: [Pause]?

    /// Where the row's time range ends: the save for focus, the finish for a break.
    var end: Date { endedAt ?? completedAt ?? startedAt }

    /// The whole run from start to end, pauses included. This is the Length shown everywhere.
    var lengthSeconds: Int { Int(end.timeIntervalSince(startedAt)) }

    /// The same session with the edit sheet's values. A break ends at `end`. A focus session keeps whether it
    /// finished, and its clock still hits zero as long after the start as before, kept within the new times.
    /// Pauses keep their times, cut to fit within the new start and end; any left under a minute are dropped.
    /// The time counted stays the same unless the new times, less the pauses, are too short for it.
    func edited(kind: Kind, start: Date, end: Date) -> Session {
        let pauses = self.pauses?.compactMap { pause -> Pause? in
            let cut = Pause(start: max(pause.start, start), end: min(pause.end, end))
            return cut.seconds >= 60 ? cut : nil
        }
        let paused = pauses?.reduce(0) { $0 + $1.seconds } ?? 0
        let durationSeconds = min(self.durationSeconds, Int(end.timeIntervalSince(start)) - paused)
        switch kind {
        case .rest:
            return Session(id: id, kind: .rest, startedAt: start, completedAt: end, endedAt: nil, durationSeconds: durationSeconds, pauses: pauses)
        case .focus:
            let completed = completedAt.map { completedAt in
                let moved = start.addingTimeInterval(completedAt.timeIntervalSince(startedAt))
                return min(max(moved, start.addingTimeInterval(TimeInterval(durationSeconds))), end)
            }
            return Session(id: id, kind: .focus, startedAt: start, completedAt: completed, endedAt: end, durationSeconds: durationSeconds, pauses: pauses)
        }
    }

    /// One running stretch or pause, for the segment list.
    struct Segment: Hashable {
        let start: Date
        let end: Date
        let isPause: Bool
        var seconds: Int { Int(end.timeIntervalSince(start)) }
    }

    /// Running stretches and pauses in order, from start to end. Nil without recorded pauses.
    var segments: [Segment]? {
        guard let pauses, !pauses.isEmpty else { return nil }
        var segments: [Segment] = []
        var cursor = startedAt
        for pause in pauses {
            if pause.start > cursor { segments.append(Segment(start: cursor, end: pause.start, isPause: false)) }
            segments.append(Segment(start: pause.start, end: pause.end, isPause: true))
            cursor = pause.end
        }
        if end > cursor { segments.append(Segment(start: cursor, end: end, isPause: false)) }
        return segments
    }

    /// Time spent paused, which the duration leaves out. Waiting at zero for Reset isn't a pause, and under a minute doesn't count.
    /// Older sessions without recorded pauses work it out from the times.
    var pausedSeconds: Int {
        let paused = pauses.map { $0.reduce(0) { $0 + $1.seconds } }
            ?? Int((completedAt ?? end).timeIntervalSince(startedAt)) - durationSeconds
        return paused >= 60 ? paused : 0
    }
}
