import Foundation

/// One saved run. Matches the website's session shape (see docs/pet-design.md).
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
}
