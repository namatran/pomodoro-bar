import SwiftUI

/// Today's sessions, made up until saving is wired to real storage. Runs saved by Reset are added in memory.
@MainActor
final class MockToday: ObservableObject {
    @Published private(set) var sessions: [Session]

    init() {
        let day = Calendar.current.startOfDay(for: Date())
        func at(_ hour: Int, _ minute: Int) -> Date { day.addingTimeInterval(TimeInterval(hour * 3600 + minute * 60)) }
        sessions = [
            Session(id: UUID(), startedAt: at(9, 0), completedAt: at(9, 25), endedAt: at(9, 26), durationSeconds: 25 * 60),
            // Paused for a minute, so it hit zero at 9:58, and Reset came a few minutes later.
            Session(id: UUID(), startedAt: at(9, 32), completedAt: at(9, 58), endedAt: at(10, 2), durationSeconds: 25 * 60),
            Session(id: UUID(), startedAt: at(11, 10), completedAt: nil, endedAt: at(11, 22), durationSeconds: 12 * 60),
        ]
    }

    var totalSeconds: Int { sessions.reduce(0) { $0 + $1.durationSeconds } }

    func add(_ session: Session) { sessions.append(session) }

    func delete(_ id: UUID) { sessions.removeAll { $0.id == id } }
}

/// Count, total, and the sessions newest first. Click a row for its ⌫ button; the ⌫ key works too.
struct TodayTab: View {
    @ObservedObject var today: MockToday

    @State private var selected: UUID?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(today.sessions.count) 🍅 · \(Self.length(today.totalSeconds))")
                .font(.headline)
            if today.sessions.isEmpty {
                Text("No sessions yet today")
                    .foregroundStyle(.secondary)
            }
            ForEach(today.sessions.reversed()) { session in
                row(session)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        // A click outside the rows clears the selection.
        .onTapGesture { selected = nil }
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onKeyPress(.delete) {
            guard let selected else { return .ignored }
            delete(selected)
            return .handled
        }
        .onChange(of: focused) {
            if !focused { selected = nil }
        }
    }

    private func row(_ session: Session) -> some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Text(Self.times(session))
                    .monospacedDigit()
                if session.completedAt == nil {
                    Text("stopped early")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
            Text(Self.length(session.durationSeconds))
                .monospacedDigit()
                .foregroundStyle(.secondary)
            if selected == session.id {
                Button { delete(session.id) } label: { Image(systemName: "delete.left") }
                    .buttonStyle(.borderless)
                    .help("Delete session")
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(selected == session.id ? Color.accentColor.opacity(0.18) : .clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selected = selected == session.id ? nil : session.id
            focused = true
        }
    }

    private func delete(_ id: UUID) {
        today.delete(id)
        selected = nil
    }

    /// Start → hit zero → reset, or start → reset when stopped early. No AM/PM, to fit the row.
    private static func times(_ session: Session) -> String {
        [session.startedAt, session.completedAt, session.endedAt]
            .compactMap { $0?.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute()) }
            .joined(separator: " → ")
    }

    /// 1500 → "25m", 3900 → "1h 05m".
    private static func length(_ seconds: Int) -> String {
        let minutes = seconds / 60
        return minutes < 60 ? "\(minutes)m" : String(format: "%dh %02dm", minutes / 60, minutes % 60)
    }
}
