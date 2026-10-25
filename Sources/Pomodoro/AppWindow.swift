import AppKit
import SwiftUI

/// The app's own window. While it's open the app shows in the Dock and ⌘Tab, so it can't get lost behind other windows.
@MainActor
final class AppWindowController: NSObject, NSWindowDelegate {
    private let window: NSWindow

    init(timer: PomodoroTimer, sessions: SessionStore) {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 720),
            // The glow runs up under a see-through title bar.
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init()
        window.title = "Pomodoro"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 440, height: 480)
        window.appearance = WindowTheme.current.appearance
        window.contentView = NSHostingView(rootView: AppWindowView(timer: timer, sessions: sessions) { [weak self] theme in
            self?.apply(theme)
        })
        window.center()
        // Restores the last size and position, if there is one.
        window.setFrameAutosaveName("AppWindow")
        window.delegate = self
    }

    func show() {
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    /// Crossfades the whole window to the new look over 250ms, like the site. It's a fade with no movement,
    /// so it stays under Reduce motion too.
    private func apply(_ theme: WindowTheme) {
        if let view = window.contentView {
            view.wantsLayer = true
            let fade = CATransition()
            fade.type = .fade
            fade.duration = 0.25
            fade.timingFunction = CAMediaTimingFunction(name: .default)
            view.layer?.add(fade, forKey: "theme")
        }
        window.appearance = theme.appearance
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

/// The theme control, the timer, the last focus session, then every day's sessions, newest day first, each with
/// its focus total. Click a row for its ⌫ button; the ⌫ key works too.
struct AppWindowView: View {
    @ObservedObject var timer: PomodoroTimer
    @ObservedObject var sessions: SessionStore
    let onTheme: (WindowTheme) -> Void

    @State private var selected: UUID?
    @FocusState private var focused: Bool

    var body: some View {
        let days = sessions.byDay
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                // Top right, level with the window buttons on the left.
                ThemeControl(onChange: onTheme)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.bottom, -24)
                // The pet's own timer, so the two always agree.
                TimerTab(timer: timer, clockSize: 56, glass: true)
                    .frame(maxWidth: 360)
                    .padding(.vertical, 24)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity)
                    .glassPane()
                if let last = sessions.sessions.filter({ $0.kind == .focus }).max(by: { $0.end < $1.end }) {
                    LastSessionCard(session: last)
                }
                if days.isEmpty {
                    EmptyHistory()
                }
                LazyVStack(spacing: 14) {
                    ForEach(days, id: \.day) { day in
                        DayCard(day: day.day, sessions: day.sessions, selected: selected, onSelect: select, onDelete: delete)
                    }
                }
            }
            // One centred column, like the site, starting clear of the window buttons.
            .frame(maxWidth: 720)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 48)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            // A click outside the rows clears the selection.
            .onTapGesture { selected = nil }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GlassGround())
        .fontDesign(.rounded)
        .foregroundStyle(Glass.ink)
        .tint(Glass.tomato)
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

    private func select(_ id: UUID) {
        selected = selected == id ? nil : id
        focused = true
    }

    private func delete(_ id: UUID) {
        sessions.delete(id)
        selected = nil
    }
}

/// The site's empty state: the tomato says it's ready, over a short line on how sessions get here.
struct EmptyHistory: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 6) {
                TomatoView(state: .idle)
                    .frame(width: 84, height: 84)
                SpeechBubble(text: "ready when you are", tail: .left)
                    .padding(.bottom, 26)
            }
            Text("No sessions yet")
                .font(.system(size: 22, weight: .bold))
                .padding(.top, 18)
            Text("Focus for a minute or more, then press Reset, and the session shows up here.")
                .font(.system(size: 15))
                .foregroundStyle(Glass.inkSoft)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
                .padding(.top, 8)
        }
        .padding(.horizontal, 32)
        .padding(.top, 36)
        .padding(.bottom, 32)
        .frame(maxWidth: .infinity)
        .glassPane()
    }
}

/// The last focus run, like the site's Last session: the tomato says when it ended, then Start, End and Focus
/// as big figures, then the day line.
struct LastSessionCard: View {
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom, spacing: 12) {
                Text("Last session")
                    .font(.system(size: 22, weight: .bold))
                    .padding(.bottom, 6)
                Spacer()
                HStack(spacing: 4) {
                    // Refreshes so "ended 3 min ago" keeps counting.
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        SpeechBubble(text: SiteFormat.endedLine(session.end, now: context.date), tail: .right)
                    }
                    TomatoView(state: .celebrate)
                        .frame(width: 56, height: 56)
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    figure("Start", SiteFormat.time(session.startedAt))
                    figure("End", SiteFormat.time(session.end))
                    figure("Focus", SiteFormat.minutes(session.durationSeconds), accent: true)
                }
                Rectangle()
                    .fill(Glass.hairline)
                    .frame(height: 1)
                    .padding(.top, 16)
                Text(dayLine)
                    .font(.system(size: 14))
                    .monospacedDigit()
                    .foregroundStyle(Glass.inkSoft)
                    .padding(.top, 14)
            }
            .padding(.horizontal, 28)
            .padding(.top, 22)
            .padding(.bottom, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassPane()
        }
    }

    /// "Thursday, Oct 22 · Stopped early · Paused 3 min, not counted as focus"
    private var dayLine: String {
        var parts = [session.end.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())]
        if session.completedAt == nil { parts.append("Stopped early") }
        if session.pausedSeconds > 0 { parts.append("Paused \(SiteFormat.minutesText(session.pausedSeconds)), not counted as focus") }
        return parts.joined(separator: " · ")
    }

    /// A Label over a Figure, with its units set small. Only Focus takes the tomato red.
    private func figure(_ label: String, _ parts: [(String, String?)], accent: Bool = false) -> some View {
        var figure = Text("")
        for (i, part) in parts.enumerated() {
            figure = figure + Text(i == 0 ? part.0 : " \(part.0)")
            if let unit = part.1 {
                figure = figure + Text(" \(unit)")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(accent ? Glass.tomato : Glass.inkSoft)
            }
        }
        return VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Glass.inkSoft)
            figure
                .font(.system(size: 40, weight: .semibold))
                .tracking(-0.8)
                .monospacedDigit()
                .foregroundStyle(accent ? Glass.tomato : Glass.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The site's wording for times and lengths, so the window reads the same.
enum SiteFormat {
    /// 1500 → [("25", "min")], 3900 → [("1", "h"), ("5", "min")], 7200 → [("2", "h")].
    static func minutes(_ seconds: Int) -> [(String, String?)] {
        let minutes = Int((Double(seconds) / 60).rounded())
        if minutes < 60 { return [("\(minutes)", "min")] }
        let hours = ("\(minutes / 60)", Optional("h"))
        return minutes % 60 == 0 ? [hours] : [hours, ("\(minutes % 60)", "min")]
    }

    /// "25 min", "1 h 5 min".
    static func minutesText(_ seconds: Int) -> String {
        minutes(seconds).map { [$0.0, $0.1].compactMap { $0 }.joined(separator: " ") }.joined(separator: " ")
    }

    /// "9:32" with "AM" apart so it can be set small, or just "21:32" where the clock is 24-hour.
    static func time(_ date: Date) -> [(String, String?)] {
        let clock = date.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
        guard usesAMPM else { return [(clock, nil)] }
        return [(clock, periodFormatter.string(from: date))]
    }

    /// "9:32 AM", as one string for table rows.
    static func timeText(_ date: Date) -> String {
        time(date).map { [$0.0, $0.1].compactMap { $0 }.joined(separator: " ") }.joined(separator: " ")
    }

    /// The tomato's line: "ended 12 min ago", "ended yesterday", "last one: tue", "last one: oct 14".
    static func endedLine(_ ended: Date, now: Date) -> String {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: ended), to: calendar.startOfDay(for: now)).day ?? 0
        if days == 0 {
            let minutes = Int((now.timeIntervalSince(ended) / 60).rounded())
            if minutes < 1 { return "ended just now" }
            if minutes < 60 { return "ended \(minutes) min ago" }
            return "ended \(Int((Double(minutes) / 60).rounded())) h ago"
        }
        if days == 1 { return "ended yesterday" }
        if days < 7 { return "last one: \(ended.formatted(.dateTime.weekday(.abbreviated)))" }
        return "last one: \(ended.formatted(.dateTime.month(.abbreviated).day()))"
    }

    private static let usesAMPM = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .current)?.contains("a") ?? false

    private static let periodFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "a"
        return formatter
    }()
}
