import Foundation

/// One saved focus run. Matches the website's session shape (see docs/pet-design.md).
struct Session: Identifiable, Equatable {
    let id: UUID
    /// First start of the focus run.
    let startedAt: Date
    /// When the clock hit zero; nil if it was stopped early.
    let completedAt: Date?
    /// When Reset or Quit saved it.
    let endedAt: Date
    /// Focus time counted down, not counting pauses.
    let durationSeconds: Int
}
