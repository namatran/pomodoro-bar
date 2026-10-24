import SwiftUI

/// One day, like the site's: a glass card that opens and closes, with the day, its focus count and total,
/// then a table of the day's sessions, newest first. Clicking a row selects it and shows its ⌫ button.
struct DayCard: View {
    let day: Date
    /// Oldest first, as `SessionStore.byDay` gives them.
    let sessions: [Session]
    let selected: UUID?
    let onSelect: (UUID) -> Void
    let onDelete: (UUID) -> Void

    @State private var isOpen = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Fixed columns, so start and end times line up from one day to the next.
    private static let startWidth: CGFloat = 100
    private static let lengthWidth: CGFloat = 76

    var body: some View {
        let focus = sessions.filter { $0.kind == .focus }
        VStack(spacing: 0) {
            Button {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { isOpen.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Glass.inkSoft)
                        .rotationEffect(.degrees(isOpen ? 0 : -90))
                    Text(label)
                        .font(.system(size: 18, weight: .bold))
                        .tracking(-0.18)
                    Text("\(focus.count)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Glass.inkSoft)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Glass.chip))
                        .accessibilityLabel(focus.count == 1 ? "1 session" : "\(focus.count) sessions")
                    Spacer()
                    Text(SiteFormat.minutesText(focus.reduce(0) { $0 + $1.durationSeconds }))
                        .font(.system(size: 22, weight: .semibold))
                        .tracking(-0.44)
                        .monospacedDigit()
                }
                .padding(.horizontal, 24)
                .frame(minHeight: 60)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isOpen {
                table
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            }
        }
        .glassPane()
    }

    private var table: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("Start").frame(width: Self.startWidth, alignment: .leading)
                Text("End").frame(maxWidth: .infinity, alignment: .leading)
                Text("Length").frame(width: Self.lengthWidth, alignment: .trailing)
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Glass.inkSoft)
            .padding(.horizontal, 12)
            .padding(.top, 2)
            .padding(.bottom, 8)

            ForEach(sessions.reversed()) { session in
                VStack(spacing: 0) {
                    Rectangle().fill(Glass.hairline).frame(height: 1)
                    row(session)
                }
            }
        }
    }

    private func row(_ session: Session) -> some View {
        let isSelected = selected == session.id
        return HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(SiteFormat.timeText(session.startedAt))
                .frame(width: Self.startWidth, alignment: .leading)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(SiteFormat.timeText(session.end))
                if let notes = Self.notes(session) {
                    Text(notes)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Glass.inkSoft)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Glass.chip))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(SiteFormat.minutesText(session.durationSeconds))
                .foregroundStyle(Glass.inkSoft)
                .frame(width: Self.lengthWidth, alignment: .trailing)
            if isSelected {
                Button { onDelete(session.id) } label: { Image(systemName: "delete.left") }
                    .buttonStyle(.borderless)
                    .help("Delete session")
                    .padding(.leading, 10)
            }
        }
        .font(.system(size: 15))
        .monospacedDigit()
        .lineLimit(1)
        // Break rows are all Soft Ink.
        .foregroundStyle(session.kind == .rest ? Glass.inkSoft : Glass.ink)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Glass.chip : .clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { onSelect(session.id) }
    }

    /// "Today, Sat", "Yesterday, Fri" or "Oct 14, Wed".
    private var label: String {
        let calendar = Calendar.current
        let weekday = day.formatted(.dateTime.weekday(.abbreviated))
        if calendar.isDateInToday(day) { return "Today, \(weekday)" }
        if calendar.isDateInYesterday(day) { return "Yesterday, \(weekday)" }
        let date = calendar.isDate(day, equalTo: .now, toGranularity: .year)
            ? day.formatted(.dateTime.month(.abbreviated).day())
            : day.formatted(.dateTime.month(.abbreviated).day().year())
        return "\(date), \(weekday)"
    }

    /// "break", "stopped early" and "paused 3 min", joined into one chip.
    private static func notes(_ session: Session) -> String? {
        var notes: [String] = []
        if session.kind == .rest { notes.append("break") }
        if session.kind == .focus && session.completedAt == nil { notes.append("stopped early") }
        if session.pausedSeconds > 0 { notes.append("paused \(SiteFormat.minutesText(session.pausedSeconds))") }
        return notes.isEmpty ? nil : notes.joined(separator: " · ")
    }
}
