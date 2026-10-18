import SwiftUI

/// Phase picker, the clock, Start/Pause and Reset. Before a run starts, click the clock and
/// type digits that fill in from the right, like Google's timer.
struct TimerTab: View {
    @ObservedObject var timer: PomodoroTimer

    /// Digits typed so far, newest last; nil when not editing.
    @State private var digits: String?
    @FocusState private var editing: Bool

    var body: some View {
        VStack(spacing: 10) {
            Picker("Phase", selection: Binding(get: { timer.phase }, set: { timer.select($0) })) {
                ForEach(Phase.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .disabled(!timer.isFresh)

            Text(digits.map(Self.format) ?? timer.remaining.longClock)
                .font(.system(size: 34, weight: .semibold, design: .monospaced))
                .foregroundStyle(digits == nil ? Color.primary : Color.accentColor)
                // Overlaid rather than laid out, so the digits don't shift when it appears.
                .overlay(alignment: .trailing) {
                    if digits != nil { BlinkingCaret().offset(x: 6) }
                }
                .focusable()
                .focused($editing)
                .focusEffectDisabled()
                .onTapGesture { beginEditing() }
                .onKeyPress(phases: .down) { handleKey($0) }
                .help(timer.canType ? "Click to type a time" : "")

            Text(digits == nil ? " " : "Enter to start · Esc to cancel")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button(timer.isRunning ? "Pause" : "Start") {
                    timer.isRunning ? timer.pause() : timer.start()
                }
                .buttonStyle(.borderedProminent)
                .disabled(timer.isFinished)
                Button("Reset") { timer.reset() }
            }
        }
        .onChange(of: editing) {
            if !editing { digits = nil }
        }
    }

    private func beginEditing() {
        guard timer.canType else { return }
        digits = ""
        editing = true
    }

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        guard let typed = digits else { return .ignored }
        switch press.key {
        case .return:
            let seconds = Self.seconds(typed)
            editing = false
            if seconds > 0 { timer.start(seconds: seconds) }
        case .escape:
            editing = false
        case .delete:
            if !typed.isEmpty { digits = String(typed.dropLast()) }
        default:
            guard let c = press.characters.first, c.isASCII, c.isNumber else { return .ignored }
            // Leading zeros change nothing, and hh:mm:ss holds six digits.
            if (typed.isEmpty && c == "0") || typed.count == 6 { return .handled }
            digits = typed + String(c)
        }
        return .handled
    }

    /// "2500" → "00:25:00".
    private static func format(_ digits: String) -> String {
        let padded = Array(String(repeating: "0", count: 6 - digits.count) + digits)
        return "\(String(padded[0...1])):\(String(padded[2...3])):\(String(padded[4...5]))"
    }

    /// Like Google, "90" means 90 seconds rather than being rejected.
    private static func seconds(_ digits: String) -> Int {
        let n = Int(digits) ?? 0
        return n / 10000 * 3600 + n / 100 % 100 * 60 + n % 100
    }
}

/// A text-field-style caret that blinks while typing, like Google's timer.
private struct BlinkingCaret: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            Rectangle()
                .fill(Color.accentColor)
                .frame(width: 2, height: 30)
                .opacity(Int(context.date.timeIntervalSinceReferenceDate * 2) % 2 == 0 ? 1 : 0)
        }
    }
}
