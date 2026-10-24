import AppKit
import SwiftUI

/// The app's own window. While it's open the app shows in the Dock and ⌘Tab, so it can't get lost behind other windows.
@MainActor
final class AppWindowController: NSObject, NSWindowDelegate {
    private let window: NSWindow

    init(sessions: SessionStore) {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        super.init()
        window.title = "Pomodoro"
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 340, height: 360)
        window.contentView = NSHostingView(rootView: AppWindowView(sessions: sessions))
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

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

/// Every day's sessions, newest day first, each with its focus total. Click a row for its ⌫ button; the ⌫ key works too.
struct AppWindowView: View {
    @ObservedObject var sessions: SessionStore

    @State private var selected: UUID?
    @FocusState private var focused: Bool

    var body: some View {
        let days = sessions.byDay
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                if days.isEmpty {
                    Text("No sessions yet")
                        .foregroundStyle(.secondary)
                }
                ForEach(days, id: \.day) { day in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(Self.title(day.day))
                                .font(.headline)
                            Spacer()
                            Text(SessionRow.focusSummary(day.sessions))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        ForEach(day.sessions.reversed()) { session in
                            SessionRow(session: session, isSelected: selected == session.id) { delete(session.id) }
                                .onTapGesture {
                                    selected = selected == session.id ? nil : session.id
                                    focused = true
                                }
                        }
                    }
                }
            }
            .padding(20)
            .contentShape(Rectangle())
            // A click outside the rows clears the selection.
            .onTapGesture { selected = nil }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    private func delete(_ id: UUID) {
        sessions.delete(id)
        selected = nil
    }

    /// "Today", "Yesterday", "Thursday 22 October", with the year only when it isn't this one.
    private static func title(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        let format = Date.FormatStyle.dateTime.weekday(.wide).day().month(.wide)
        return calendar.isDate(day, equalTo: .now, toGranularity: .year)
            ? day.formatted(format)
            : day.formatted(format.year())
    }
}
