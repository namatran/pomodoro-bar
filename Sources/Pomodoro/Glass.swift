import AppKit
import SwiftUI

/// The website's glass look (`~/dev/pomodoro-web/DESIGN.md`) for the app window: frosted panes over soft tomato light,
/// with a dusk version for dark mode.
enum Glass {
    static let ground = dynamic(hex(0xfff6f3), hex(0x221a1c))
    static let glowCoral = dynamic(hex(0xff7662, 0.42), hex(0xd6786c, 0.22))
    static let glowPeach = dynamic(hex(0xffa08c, 0.38), hex(0xaa646e, 0.20))
    static let glowPetal = dynamic(hex(0xffcdbe, 0.45), hex(0xe6a091, 0.10))
    static let pane = dynamic(hex(0xfff6f3, 0.55), hex(0xffd6cc, 0.14))
    /// The pane with reduced transparency: the same tint, nearly opaque.
    static let paneSolid = dynamic(hex(0xfff1ed), hex(0x413435))
    static let paneEdge = dynamic(hex(0xffffff, 0.78), hex(0xffe1da, 0.18))
    static let ink = dynamic(hex(0x1d1210), hex(0xf3e9e6))
    static let inkSoft = dynamic(hex(0x6e5550), hex(0xcdb8b2))
    /// The one accent: the last session's focus figure and focus rings.
    static let tomato = dynamic(hex(0xbf3727), hex(0xffb3a6))
    static let hairline = dynamic(hex(0x78281e, 0.10), hex(0xffffff, 0.09))
    static let chip = dynamic(hex(0xffffff, 0.7), hex(0xffffff, 0.12))
    static let pill = dynamic(hex(0x16100e), hex(0xf3e9e6))
    static let pillText = dynamic(hex(0xffffff), hex(0x221a1c))
    static let paneShadow = dynamic(hex(0xa03223, 0.10), hex(0x000000, 0.20))

    private static func dynamic(_ light: NSColor, _ dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        })
    }

    private static func hex(_ rgb: Int, _ alpha: CGFloat = 1) -> NSColor {
        NSColor(
            srgbRed: CGFloat(rgb >> 16 & 0xff) / 255,
            green: CGFloat(rgb >> 8 & 0xff) / 255,
            blue: CGFloat(rgb & 0xff) / 255,
            alpha: alpha
        )
    }
}

/// The light everything sits in: three soft glows over the ground, gradients only.
struct GlassGround: View {
    var body: some View {
        GeometryReader { proxy in
            // Sized to the window, so full screen gets the same light as the default 560 × 720 window.
            let size = max(proxy.size.width, proxy.size.height, 720)
            ZStack {
                Glass.ground
                RadialGradient(colors: [Glass.glowCoral, .clear], center: .topLeading, startRadius: 0, endRadius: size * 0.72)
                RadialGradient(colors: [Glass.glowPeach, .clear], center: .bottomTrailing, startRadius: 0, endRadius: size * 0.78)
                RadialGradient(colors: [Glass.glowPetal, .clear], center: UnitPoint(x: 0.85, y: 0.15), startRadius: 0, endRadius: size * 0.53)
            }
        }
        .ignoresSafeArea()
    }
}

/// A frosted pane with a bright edge and a soft, tinted shadow. One level deep: panes never go inside panes.
struct GlassPane: ViewModifier {
    var cornerRadius: CGFloat = 24
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            // The shadow comes from the shape alone, not the text inside, so it stays cheap while a day
            // opens or the theme fades.
            .background(
                shape.fill(reduceTransparency ? Glass.paneSolid : Glass.pane)
                    .shadow(color: Glass.paneShadow, radius: 16, y: 12)
            )
            .overlay(shape.strokeBorder(Glass.paneEdge, lineWidth: 1))
    }
}

extension View {
    func glassPane(cornerRadius: CGFloat = 24) -> some View {
        modifier(GlassPane(cornerRadius: cornerRadius))
    }
}

/// The tomato's speech bubble: lowercase, on an ink fill, with one sharp corner pointing at the tomato.
struct SpeechBubble: View {
    enum Tail { case left, right }

    let text: String
    let tail: Tail

    var body: some View {
        Text(text.lowercased())
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .foregroundStyle(Glass.pillText)
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: 16,
                    bottomLeadingRadius: tail == .left ? 4 : 16,
                    bottomTrailingRadius: tail == .right ? 4 : 16,
                    topTrailingRadius: 16,
                    style: .continuous
                )
                .fill(Glass.ink)
            )
            .shadow(color: .black.opacity(0.10), radius: 7, y: 4)
    }
}

/// The site's pill buttons, 44pt tall: solid ink for the main action, the chip fill for the rest. Disabled ones fade to half.
struct PillButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        Pill(configuration: configuration, prominent: prominent)
    }

    private struct Pill: View {
        let configuration: ButtonStyleConfiguration
        let prominent: Bool
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(prominent ? Glass.pillText : Glass.ink)
                .padding(.horizontal, 18)
                .frame(minWidth: 96, minHeight: 44)
                .background(Capsule().fill(prominent ? Glass.pill : Glass.chip))
                .contentShape(Capsule())
                .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.5)
        }
    }
}
