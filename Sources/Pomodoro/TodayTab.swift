import SwiftUI

/// Focus count and total, then the sessions newest first, with breaks dimmer. Click a row for its ⌫ button; the ⌫ key works too.
struct TodayTab: View {
    @ObservedObject var sessions: SessionStore

    @State private var selected: UUID?
    @FocusState private var focused: Bool

    var body: some View {
        let today = sessions.today
        // Breaks are listed but don't count toward the header.
        let focus = today.filter { $0.kind == .focus }
        VStack(alignment: .leading, spacing: 8) {
            Text("\(focus.count) 🍅 · \(Self.length(focus.reduce(0) { $0 + $1.durationSeconds }))")
                .font(.headline)
            if today.isEmpty {
                Text("No sessions yet today")
                    .foregroundStyle(.secondary)
            }
            ForEach(today.reversed()) { session in
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
                if session.kind == .rest {
                    // Breaks are a plain start → end, dimmer than focus.
                    Text("☕ \(Self.time(session.startedAt)) → \(Self.time(session.end))")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(Self.time(session.startedAt)) → \(Self.time(session.end))")
                        .monospacedDigit()
                    if let completedAt = session.completedAt {
                        Text("finished at \(Self.time(completedAt))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("stopped early")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
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
        sessions.delete(id)
        selected = nil
    }

    /// No AM/PM, to fit the row.
    private static func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
    }

    /// 1500 → "25m", 3900 → "1h 05m".
    private static func length(_ seconds: Int) -> String {
        let minutes = seconds / 60
        return minutes < 60 ? "\(minutes)m" : String(format: "%dh %02dm", minutes / 60, minutes % 60)
    }
}
