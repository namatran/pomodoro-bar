import AppKit
import SwiftUI

/// Can become key so the Timer tab can take typing.
final class PopoutPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// Buttons respond to the first click even while another app is active.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// The panel beside the pet: opens on whichever side has room, clamped on screen, and follows the pet when dragged.
@MainActor
final class PopoutController {
    private static let openKey = "popoutOpen"
    private static let gap: CGFloat = 8
    private static let margin: CGFloat = 8

    /// Whether it was open when the app last ran.
    static var wasOpen: Bool { UserDefaults.standard.bool(forKey: openKey) }

    private let panel: PopoutPanel
    private var anchor: NSRect = .zero
    private var resizeObserver: NSObjectProtocol?

    var isOpen: Bool { panel.isVisible }

    init(timer: PomodoroTimer) {
        panel = PopoutPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.contentView = FirstMouseHostingView(rootView: PopoutView(timer: timer, onClose: { [weak self] in self?.close() }))

        // The content's height changes with it, so re-centre on the pet.
        resizeObserver = NotificationCenter.default.addObserver(forName: NSWindow.didResizeNotification, object: panel, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.place() }
        }
    }

    func toggle(anchor: NSRect) {
        isOpen ? close() : open(anchor: anchor)
    }

    func open(anchor: NSRect) {
        self.anchor = anchor
        if let content = panel.contentView { panel.setContentSize(content.fittingSize) }
        place()
        panel.orderFrontRegardless()
        panel.invalidateShadow()
        UserDefaults.standard.set(true, forKey: Self.openKey)
    }

    func close() {
        panel.orderOut(nil)
        UserDefaults.standard.set(false, forKey: Self.openKey)
    }

    /// Track the pet while it's being dragged.
    func follow(anchor: NSRect) {
        self.anchor = anchor
        if isOpen { place() }
    }

    private func place() {
        let size = panel.frame.size
        let center = NSPoint(x: anchor.midX, y: anchor.midY)
        let screen = (NSScreen.screens.first { $0.frame.contains(center) } ?? NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        let onLeft = anchor.midX > screen.midX
        var x = onLeft ? anchor.minX - Self.gap - size.width : anchor.maxX + Self.gap
        var y = anchor.midY - size.height / 2
        x = min(max(x, screen.minX + Self.margin), screen.maxX - size.width - Self.margin)
        y = min(max(y, screen.minY + Self.margin), screen.maxY - size.height - Self.margin)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

struct PopoutView: View {
    @ObservedObject var timer: PomodoroTimer
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Timer").font(.headline)
                Spacer()
                Button(action: onClose) { Image(systemName: "xmark") }
                    .buttonStyle(.borderless)
                    .help("Close")
            }
            TimerTab(timer: timer)
        }
        .padding(14)
        .frame(width: 260)
        .background(VisualEffectBackground())
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct TimerTab: View {
    @ObservedObject var timer: PomodoroTimer

    var body: some View {
        VStack(spacing: 10) {
            Text(timer.phase.label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(timer.remaining.longClock)
                .font(.system(size: 34, weight: .semibold, design: .monospaced))
            HStack {
                Button(timer.isRunning ? "Pause" : "Start") {
                    timer.isRunning ? timer.pause() : timer.start()
                }
                .buttonStyle(.borderedProminent)
                .disabled(timer.isFinished)
                Button("Reset") { timer.reset() }
            }
        }
    }
}

/// Native frosted background that follows light and dark mode.
struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
