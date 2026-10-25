import AppKit
import SwiftUI

/// The window's light or dark look. System follows macOS; the other two pin the window, and nothing else, to one look.
enum WindowTheme: String, CaseIterable {
    case system, light, dark

    static let key = "windowTheme"

    static var current: WindowTheme {
        UserDefaults.standard.string(forKey: key).flatMap(WindowTheme.init) ?? .system
    }

    /// Set on the window, so the dynamic colours in `Glass` pick their light or dark version.
    var appearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }

    var label: String {
        switch self {
        case .system: "Match system"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var symbol: String {
        switch self {
        case .system: "display"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }
}

/// The site's theme control: System, Light and Dark as three icon buttons on a chip-coloured pill.
struct ThemeControl: View {
    @AppStorage(WindowTheme.key) private var theme = WindowTheme.system
    /// Applies the choice to the window, which SwiftUI can't reach on its own.
    let onChange: (WindowTheme) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(WindowTheme.allCases, id: \.self) { option in
                button(option)
            }
        }
        .background(Capsule().fill(Glass.chip))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Appearance")
    }

    /// The chosen one sits on the ink pill, like the site's pressed button.
    private func button(_ option: WindowTheme) -> some View {
        let chosen = theme == option
        return Button {
            theme = option
            onChange(option)
        } label: {
            Image(systemName: option.symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(chosen ? Glass.pillText : Glass.ink)
                .frame(width: 36, height: 36)
                .background(Circle().fill(chosen ? Glass.pill : Color.clear))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(option.label)
        .accessibilityLabel(option.label)
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }
}
