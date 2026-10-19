import AppKit
import SwiftUI

/// Can become key so the Timer tab can take typing.
final class PopoutPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// Buttons respond to the first click even while another app is active, and a click
/// makes the panel key so typing reaches it.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        super.mouseDown(with: event)
    }
}

/// The panel beside the pet: opens on whichever side has room, clamped on screen, and follows the pet when dragged.
@MainActor
final class PopoutController {
    private static let openKey = "popoutOpen"

    /// Whether it was open when the app last ran.
    static var wasOpen: Bool { UserDefaults.standard.bool(forKey: openKey) }

    private let panel: PopoutPanel
    private var anchor: NSRect = .zero
    private var resizeObserver: NSObjectProtocol?

    var isOpen: Bool { panel.isVisible }

    /// Where it sits while open, for the alarm bubble to stack on.
    var openFrame: NSRect? { isOpen ? panel.frame : nil }

    /// Called after it opens, closes or moves, so the bubble can make way.
    var onLayout: () -> Void = {}

    init(timer: PomodoroTimer, stopwatch: Stopwatch, sessions: SessionStore) {
        panel = PopoutPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.contentView = FirstMouseHostingView(rootView: PopoutView(timer: timer, stopwatch: stopwatch, sessions: sessions, onClose: { [weak self] in self?.close() }))

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
        onLayout()
    }

    func close() {
        panel.orderOut(nil)
        UserDefaults.standard.set(false, forKey: Self.openKey)
        onLayout()
    }

    /// Out of sight along with the pet, but still remembered as open.
    func hide() {
        panel.orderOut(nil)
    }

    /// Track the pet while it's being dragged.
    func follow(anchor: NSRect) {
        self.anchor = anchor
        if isOpen { place() }
    }

    private func place() {
        panel.setFrameOrigin(Placement.beside(anchor, size: panel.frame.size))
        onLayout()
    }
}

enum PopoutTab: String, CaseIterable {
    case timer = "Timer", stopwatch = "Stopwatch", today = "Today"
}

struct PopoutView: View {
    @ObservedObject var timer: PomodoroTimer
    @ObservedObject var stopwatch: Stopwatch
    @ObservedObject var sessions: SessionStore
    let onClose: () -> Void

    @State private var tab = PopoutTab.timer

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Picker("Tab", selection: $tab) {
                    ForEach(PopoutTab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Button(action: onClose) { Image(systemName: "xmark") }
                    .buttonStyle(.borderless)
                    .help("Close")
            }
            switch tab {
            case .timer: TimerTab(timer: timer)
            case .stopwatch: StopwatchTab(stopwatch: stopwatch)
            case .today: TodayTab(sessions: sessions)
            }
        }
        .padding(14)
        .frame(width: 260)
        .background(VisualEffectBackground())
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
