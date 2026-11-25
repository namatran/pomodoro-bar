import SwiftUI

/// The window's edit sheet: Focus or Break, start and end. The length follows from start and end.
struct SessionEditor: View {
    let session: Session
    let onSave: (Session) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var kind: Session.Kind
    @State private var start: Date
    @State private var end: Date

    init(session: Session, onSave: @escaping (Session) -> Void) {
        self.session = session
        self.onSave = onSave
        _kind = State(initialValue: session.kind)
        _start = State(initialValue: session.startedAt)
        _end = State(initialValue: session.end)
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
                    Text(end > start ? SiteFormat.minutesText(Int(end.timeIntervalSince(start))) : "–")
                        .monospacedDigit()
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
                    onSave(session.edited(kind: kind, start: start, end: end))
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

    /// Why Save is off, or nil when the values make a session.
    private var problem: String? {
        end <= start ? "End must be after Start." : nil
    }
}
