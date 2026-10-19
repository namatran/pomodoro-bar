import AppKit
import Combine
import SwiftUI

enum PetSize: String, CaseIterable {
    case small, medium, large

    static let key = "petSize"

    static var saved: PetSize {
        UserDefaults.standard.string(forKey: key).flatMap(PetSize.init(rawValue:)) ?? .medium
    }

    var width: CGFloat {
        switch self {
        case .small: return 72
        case .medium: return 96
        case .large: return 128
        }
    }

    var label: String { rawValue.capitalized }
}

/// The floating pet: a borderless panel that bobs, drags, and remembers where it sat.
@MainActor
final class PetController {
    static let bob: CGFloat = 3

    private static let originKey = "petOrigin"
    private let panel: NSPanel
    private let popout: PopoutController
    private let bubble: BubbleController
    private let timer: PomodoroTimer
    private var alarmWatch: AnyCancellable?
    let sprites = Sprites()

    /// The right-click menu's Hide pet; the app delegate owns visibility.
    var onHide: () -> Void = {}

    init(timer: PomodoroTimer, stopwatch: Stopwatch, sessions: SessionStore, visible: Bool) {
        let size = Self.panelSize(PetSize.saved)
        panel = NSPanel(
            contentRect: NSRect(origin: Self.savedOrigin(size: size) ?? Self.defaultOrigin(size: size), size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        popout = PopoutController(timer: timer, stopwatch: stopwatch, sessions: sessions)
        bubble = BubbleController(timer: timer)
        self.timer = timer
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        // Every Space, including over full-screen apps, where the menu bar is hidden.
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false

        let mouse = PetMouseView(frame: NSRect(origin: .zero, size: size))
        mouse.onClick = { [weak self] in
            guard let self else { return }
            // While it rings, a click only silences it.
            if timer.isAlarming {
                timer.stopAlarm()
            } else {
                popout.toggle(anchor: panel.frame)
            }
        }
        mouse.onMove = { [weak self] in self?.petMoved() }
        mouse.onDragEnd = { origin in
            UserDefaults.standard.set([origin.x, origin.y], forKey: Self.originKey)
        }
        mouse.onRightClick = { [weak self, weak mouse] event in
            guard let self, let mouse else { return }
            NSMenu.popUpContextMenu(makeMenu(), with: event, for: mouse)
        }
        let host = NSHostingView(rootView: PetView(timer: timer, stopwatch: stopwatch, sprites: sprites))
        host.frame = mouse.bounds
        host.autoresizingMask = [.width, .height]
        mouse.addSubview(host)
        panel.contentView = mouse

        popout.onLayout = { [weak self] in self?.placeBubble() }
        alarmWatch = timer.$isAlarming.removeDuplicates().sink { [weak self] ringing in
            guard let self else { return }
            if ringing && panel.isVisible {
                bubble.show(pet: panel.frame, popout: popout.openFrame)
            } else {
                bubble.hide()
            }
        }

        setVisible(visible)
    }

    /// Hiding takes the popout and bubble along; showing brings back whichever were up.
    func setVisible(_ visible: Bool) {
        if visible {
            panel.orderFrontRegardless()
            if PopoutController.wasOpen { popout.open(anchor: panel.frame) }
            if timer.isAlarming { bubble.show(pet: panel.frame, popout: popout.openFrame) }
        } else {
            panel.orderOut(nil)
            popout.hide()
            bubble.hide()
        }
    }

    private func placeBubble() {
        bubble.place(pet: panel.frame, popout: popout.openFrame)
    }

    /// Bring the popout and bubble along after the pet moves.
    private func petMoved() {
        popout.follow(anchor: panel.frame)
        placeBubble()
    }

    /// Room for the sprite plus its bob.
    private static func panelSize(_ size: PetSize) -> NSSize {
        NSSize(width: size.width, height: size.width + bob * 2)
    }

    /// Grows or shrinks about the pet's bottom centre, so it stays standing on the same spot.
    private func setSize(_ size: PetSize) {
        UserDefaults.standard.set(size.rawValue, forKey: PetSize.key)
        let old = panel.frame, new = Self.panelSize(size)
        let origin = NSPoint(x: old.midX - new.width / 2, y: old.minY)
        panel.setFrame(NSRect(origin: origin, size: new), display: true)
        UserDefaults.standard.set([origin.x, origin.y], forKey: Self.originKey)
        petMoved()
    }

    private func resetPosition() {
        UserDefaults.standard.removeObject(forKey: Self.originKey)
        panel.setFrameOrigin(Self.defaultOrigin(size: panel.frame.size))
        petMoved()
    }

    /// Built on each right-click so the checkmarks are current.
    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(lengthMenu("Focus length", key: Settings.workKey, choices: [15, 20, 25, 30, 45, 50, 60]))
        menu.addItem(lengthMenu("Break length", key: Settings.breakKey, choices: [5, 10, 15, 20]))
        let current = PetSize.saved
        menu.addItem(Self.submenu("Pet size", PetSize.allCases.map { size in
            let item = MenuItem(size.label) { [weak self] in self?.setSize(size) }
            item.state = size == current ? .on : .off
            return item
        }))
        menu.addItem(.separator())
        let hide = MenuItem("Hide pet") { [weak self] in self?.onHide() }
        // Shown only; the hot key does the work.
        hide.keyEquivalent = "t"
        hide.keyEquivalentModifierMask = [.control, .option, .command]
        menu.addItem(hide)
        menu.addItem(MenuItem("Reset position") { [weak self] in self?.resetPosition() })
        menu.addItem(MenuItem("Reload sprites") { [weak self] in self?.sprites.reload() })
        menu.addItem(.separator())
        menu.addItem(MenuItem("Quit") { NSApplication.shared.terminate(nil) })
        return menu
    }

    /// The current length is always listed and checked, even a custom one set with the menu bar's stepper.
    private func lengthMenu(_ title: String, key: String, choices: [Int]) -> NSMenuItem {
        let current = UserDefaults.standard.integer(forKey: key)
        return Self.submenu(title, Set(choices + [current]).sorted().map { minutes in
            let item = MenuItem("\(minutes) min") { [weak self] in
                UserDefaults.standard.set(minutes, forKey: key)
                self?.timer.applySettings()
            }
            item.state = minutes == current ? .on : .off
            return item
        })
    }

    private static func submenu(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = NSMenu()
        items.forEach { item.submenu?.addItem($0) }
        return item
    }

    /// Bottom right of the main screen, clear of cost and claudepet higher up the right edge.
    private static func defaultOrigin(size: NSSize) -> NSPoint {
        let frame = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        return NSPoint(x: frame.maxX - size.width - 28, y: frame.minY + 80)
    }

    /// The dragged position, unless that screen is gone.
    private static func savedOrigin(size: NSSize) -> NSPoint? {
        guard let xy = UserDefaults.standard.array(forKey: originKey) as? [Double], xy.count == 2 else { return nil }
        let rect = NSRect(origin: NSPoint(x: xy[0], y: xy[1]), size: size)
        guard NSScreen.screens.contains(where: { $0.visibleFrame.intersects(rect) }) else { return nil }
        return rect.origin
    }
}

/// Takes every mouse event over the pet: a short press is a click, anything past the slop is a drag.
final class PetMouseView: NSView {
    var onClick: () -> Void = {}
    var onMove: () -> Void = {}
    var onDragEnd: (NSPoint) -> Void = { _ in }
    var onRightClick: (NSEvent) -> Void = { _ in }

    private static let dragSlop: CGFloat = 4
    private var downMouse: NSPoint?
    private var downOrigin: NSPoint = .zero
    private var dragging = false

    // Swallow hits meant for the SwiftUI view inside.
    override func hitTest(_ point: NSPoint) -> NSView? {
        super.hitTest(point) == nil ? nil : self
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        // Screen coordinates, so moving the window doesn't shift the reference point.
        downMouse = NSEvent.mouseLocation
        downOrigin = window?.frame.origin ?? .zero
        dragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = downMouse, let window else { return }
        let now = NSEvent.mouseLocation
        let dx = now.x - start.x, dy = now.y - start.y
        if !dragging, hypot(dx, dy) < Self.dragSlop { return }
        dragging = true
        window.setFrameOrigin(NSPoint(x: downOrigin.x + dx, y: downOrigin.y + dy))
        onMove()
    }

    override func mouseUp(with event: NSEvent) {
        guard downMouse != nil else { return }
        downMouse = nil
        if dragging, let window {
            onDragEnd(window.frame.origin)
        } else {
            onClick()
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        onRightClick(event)
    }
}

/// A menu item that runs a closure, so the menu needs no Objective-C target.
final class MenuItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(MenuItem.fire), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) {
        fatalError("not used from nibs")
    }

    @objc private func fire() {
        handler()
    }
}

struct PetView: View {
    @ObservedObject var timer: PomodoroTimer
    @ObservedObject var stopwatch: Stopwatch
    @ObservedObject var sprites: Sprites
    @AppStorage(PetSize.key) private var size = PetSize.medium
    @State private var up = false

    var body: some View {
        let state = PetState(timer: timer, stopwatch: stopwatch)
        Group {
            if let image = sprites.image(for: state) {
                Image(nsImage: image).resizable().scaledToFit()
            } else {
                TomatoView(state: state)
            }
        }
        .frame(width: size.width, height: size.width)
        .offset(y: up ? -PetController.bob : PetController.bob)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { up = true }
        }
    }
}
