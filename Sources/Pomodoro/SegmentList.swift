import SwiftUI

/// A session's running stretches and pauses, each with its times and length. Running stretches get a
/// solid ink bar, pauses a faint one and Soft Ink text.
struct SegmentList: View {
    let segments: [Session.Segment]

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 6) {
            ForEach(segments, id: \.self) { segment in
                GridRow {
                    Capsule()
                        .fill(segment.isPause ? Glass.inkSoft.opacity(0.3) : Glass.ink)
                        .frame(width: 3, height: 14)
                    Text(segment.isPause ? "Paused" : "Running")
                    Text("\(SiteFormat.timeText(segment.start)) – \(SiteFormat.timeText(segment.end))")
                    Text(SiteFormat.minutesText(segment.seconds))
                        .gridColumnAlignment(.trailing)
                }
                .foregroundStyle(segment.isPause ? Glass.inkSoft : Glass.ink)
            }
        }
        .font(.system(size: 13))
        .monospacedDigit()
        .lineLimit(1)
    }
}
