import SwiftUI

/// A session's run as one bar, solid where the clock ran and faint where it was paused, over a line
/// with the time on the clock and each pause: "Focused 30 min · Paused 9:12–9:17, 9:25–9:28".
struct PauseBar: View {
    let session: Session
    let segments: [Session.Segment]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geometry in
                let gaps = CGFloat(segments.count - 1) * 2
                let total = max(1, segments.reduce(0) { $0 + $1.seconds })
                HStack(spacing: 2) {
                    ForEach(segments, id: \.self) { segment in
                        Capsule()
                            .fill(segment.isPause ? Glass.inkSoft.opacity(0.3) : Glass.ink)
                            .frame(width: max(2, (geometry.size.width - gaps) * CGFloat(segment.seconds) / CGFloat(total)))
                    }
                }
            }
            .frame(height: 6)
            Text(line)
                .font(.system(size: 13))
                .foregroundStyle(Glass.inkSoft)
                .monospacedDigit()
                .lineLimit(2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(line)
    }

    private var line: String {
        let ran = "\(session.kind == .focus ? "Focused" : "Ran") \(SiteFormat.minutesText(session.durationSeconds))"
        let pauses = segments.filter(\.isPause).map { "\(Self.clock($0.start))–\(Self.clock($0.end))" }
        return "\(ran) · Paused \(pauses.joined(separator: ", "))"
    }

    /// "9:12", leaving out AM or PM, which the row already shows.
    private static func clock(_ date: Date) -> String { SiteFormat.time(date)[0].0 }
}
