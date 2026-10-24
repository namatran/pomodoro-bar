import SwiftUI

/// One session in a list: focus as start → end with how it ended, breaks dimmer. Selected rows show a ⌫ button.
struct SessionRow: View {
    let session: Session
    let isSelected: Bool
    let onDelete: () -> Void

    var body: some View {
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
            if isSelected {
                Button(action: onDelete) { Image(systemName: "delete.left") }
                    .buttonStyle(.borderless)
                    .help("Delete session")
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.18) : .clear)
        )
        .contentShape(Rectangle())
    }

    /// No AM/PM, to fit the row.
    static func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
    }

    /// 1500 → "25m", 3900 → "1h 05m".
    static func length(_ seconds: Int) -> String {
        let minutes = seconds / 60
        return minutes < 60 ? "\(minutes)m" : String(format: "%dh %02dm", minutes / 60, minutes % 60)
    }

    /// The 🍅 count and focus total for a list header. Breaks don't count.
    static func focusSummary(_ sessions: [Session]) -> String {
        let focus = sessions.filter { $0.kind == .focus }
        return "\(focus.count) 🍅 · \(length(focus.reduce(0) { $0 + $1.durationSeconds }))"
    }
}
