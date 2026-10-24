import SwiftUI

/// Focus count and total, then the sessions newest first, with breaks dimmer. Click a row for its ⌫ button; the ⌫ key works too.
/// See all opens every day in the app window.
struct TodayTab: View {
    @ObservedObject var sessions: SessionStore
    let onSeeAll: () -> Void

    @State private var selected: UUID?
    @FocusState private var focused: Bool

    var body: some View {
        let today = sessions.today
        VStack(alignment: .leading, spacing: 8) {
            Text(SessionRow.focusSummary(today))
                .font(.headline)
            if today.isEmpty {
                Text("No sessions yet today")
                    .foregroundStyle(.secondary)
            }
            ForEach(today.reversed()) { session in
                SessionRow(session: session, isSelected: selected == session.id) { delete(session.id) }
                    .onTapGesture {
                        selected = selected == session.id ? nil : session.id
                        focused = true
                    }
            }
            Button("See all", action: onSeeAll)
                .buttonStyle(.link)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        // A click outside the rows clears the selection.
        .onTapGesture { selected = nil }
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
}
