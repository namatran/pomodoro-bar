import SwiftUI

/// The window's edit sheet: Focus or Break, start and end, and the length, which leaves out pauses
/// and so can't be longer than start to end.
struct SessionEditor: View {
    let session: Session
    let onSave: (Session) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var kind: Session.Kind
    @State private var start: Date
    @State private var end: Date
    @State private var minutes: Int

    init(session: Session, onSave: @escaping (Session) -> Void) {
        self.session = session
        self.onSave = onSave
        _kind = State(initialValue: session.kind)
        _start = State(initialValue: session.startedAt)
        _end = State(initialValue: session.end)
        _minutes = State(initialValue: Self.wholeMinutes(session.durationSeconds))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Edit session")
                .font(.system(size: 18, weight: .bold))
            PillPicker(selection: $kind, options: [.focus, .rest], label: { $0 == .focus ? "Focus" : "Break" }, accent: { $0 == .focus })
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow {
                    Text("Start")
                    DatePicker("Start", selection: $start).labelsHidden()
                }
                GridRow {
                    Text("End")
                    DatePicker("End", selection: $end).labelsHidden()
                }
                GridRow {
                    Text("Length")
                    HStack(spacing: 6) {
                        TextField("Length", value: $minutes, format: .number)
                            .labelsHidden()
                            .frame(width: 56)
                            .multilineTextAlignment(.trailing)
                        Stepper("Length", value: $minutes, in: 1...max(1, spanMinutes)).labelsHidden()
                        Text("min, not counting pauses")
                            .foregroundStyle(Glass.inkSoft)
                    }
                }
            }
            .font(.system(size: 14))
            if let problem {
                Text(problem)
                    .font(.system(size: 13))
                    .foregroundStyle(Glass.tomato)
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    onSave(session.edited(kind: kind, start: start, end: end, durationSeconds: durationSeconds))
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(problem != nil)
            }
        }
        .padding(24)
        .frame(width: 400)
        .fontDesign(.rounded)
    }

    /// Whole minutes from start to end, the longest the length can be.
    private var spanMinutes: Int { Int(end.timeIntervalSince(start)) / 60 }

    /// Why Save is off, or nil when the values make a session.
    private var problem: String? {
        if end <= start { return "End must be after Start." }
        if minutes < 1 { return "Length must be at least 1 min." }
        if durationSeconds > Int(end.timeIntervalSince(start)) { return "Length can't be longer than Start to End." }
        return nil
    }

    /// The stored seconds while the minutes are untouched, so opening and saving changes nothing.
    private var durationSeconds: Int {
        minutes == Self.wholeMinutes(session.durationSeconds) ? session.durationSeconds : minutes * 60
    }

    private static func wholeMinutes(_ seconds: Int) -> Int { max(1, Int((Double(seconds) / 60).rounded())) }
}
