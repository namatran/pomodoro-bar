import SwiftUI

/// Focus | Break picker, the clock, Start/Pause and Reset. While the clock isn't running, click it
/// to edit the time the way Google's timer does: the caret goes where you click, ←/→ move it,
/// digits insert at the caret and push the leftmost one off.
struct TimerTab: View {
    @ObservedObject var timer: PomodoroTimer

    /// hh:mm:ss as six digits while editing; nil otherwise.
    @State private var draft: [Int]?
    /// The digits when editing began, so an unchanged Enter does nothing.
    @State private var original: [Int] = []
    /// How many digits sit left of the caret, 0...6.
    @State private var caret = 6
    @State private var hovering = false
    @FocusState private var editing: Bool

    var body: some View {
        VStack(spacing: 10) {
            Picker("Mode", selection: Binding(get: { timer.phase }, set: { timer.select($0) })) {
                ForEach(Phase.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .disabled(!timer.isFresh)

            clock
                .focusable()
                .focused($editing)
                .focusEffectDisabled()
                .onHover { hovering = $0 }
                .onKeyPress(phases: [.down, .repeat]) { handleKey($0) }

            Text(hint)
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
            if !editing { draft = nil }
        }
    }

    /// Six digits and two colons. Each digit is its own view so a click can place the caret beside it.
    private var clock: some View {
        let digits = draft ?? Self.digits(of: timer.remaining)
        return HStack(spacing: 0) {
            ForEach(0..<6, id: \.self) { i in
                if i == 2 || i == 4 {
                    Text(":").onTapGesture { beginEditing(caret: i) }
                }
                Text("\(digits[i])")
                    .overlay(alignment: .leading) {
                        if draft != nil && caret == 0 && i == 0 { BlinkingCaret().offset(x: -2) }
                    }
                    .overlay(alignment: .trailing) {
                        if draft != nil && caret == i + 1 { BlinkingCaret().offset(x: 1) }
                    }
                    .onTapGesture { beginEditing(caret: i + 1) }
            }
        }
        .font(.system(size: 34, weight: .semibold, design: .monospaced))
        .foregroundStyle(draft == nil ? Color.primary : Color.accentColor)
    }

    private var hint: String {
        if draft != nil { return "Enter to start · Esc to cancel" }
        guard hovering else { return " " }
        if timer.isRunning { return "Pause to change the time" }
        return timer.hasStarted ? "Click to type a time · ends this run" : "Click to type a time"
    }

    private func beginEditing(caret: Int) {
        guard timer.canType else { return }
        if draft == nil {
            original = Self.digits(of: timer.remaining)
            draft = original
        }
        self.caret = caret
        editing = true
    }

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        guard var digits = draft else { return .ignored }
        switch press.key {
        case .return:
            let seconds = Self.seconds(digits)
            editing = false
            if digits != original && seconds > 0 { timer.start(seconds: seconds) }
        case .escape:
            editing = false
        case .leftArrow:
            caret = max(0, caret - 1)
        case .rightArrow:
            caret = min(6, caret + 1)
        case .home:
            caret = 0
        case .end:
            caret = 6
        case .delete, Self.backspace:
            // Remove the digit left of the caret; a zero fills in on the left, so the caret keeps its place.
            guard caret > 0 else { return .handled }
            digits.remove(at: caret - 1)
            digits.insert(0, at: 0)
            draft = digits
        default:
            guard let c = press.characters.first, c.isASCII, let digit = c.wholeNumberValue else { return .ignored }
            // Insert at the caret and drop the leftmost digit, so the caret keeps its place.
            guard caret > 0 else { return .handled }
            digits.insert(digit, at: caret)
            digits.removeFirst()
            draft = digits
        }
        return .handled
    }

    /// The Mac's ⌫ key sends U+007F, but SwiftUI's `.delete` is U+0008, so it never matches on its own.
    private static let backspace = KeyEquivalent("\u{7F}")

    /// 754 seconds → [0, 0, 1, 2, 3, 4]. Hours stop at 99.
    private static func digits(of seconds: Int) -> [Int] {
        let h = min(seconds / 3600, 99), m = seconds / 60 % 60, s = seconds % 60
        return [h / 10, h % 10, m / 10, m % 10, s / 10, s % 10]
    }

    /// Like Google, 90 in the seconds place means 90 seconds rather than being rejected.
    private static func seconds(_ d: [Int]) -> Int {
        (d[0] * 10 + d[1]) * 3600 + (d[2] * 10 + d[3]) * 60 + d[4] * 10 + d[5]
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
