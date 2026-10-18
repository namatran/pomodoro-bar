import AppKit
import SwiftUI

/// The floating pet: a borderless panel that bobs, drags, and remembers where it sat.
@MainActor
final class PetController {
    static let width: CGFloat = 96
    static let bob: CGFloat = 3

    private static let originKey = "petOrigin"
    private let panel: NSPanel
    let sprites = Sprites()

    init(timer: PomodoroTimer) {
        let size = NSSize(width: Self.width, height: Self.width + Self.bob * 2)
        panel = NSPanel(
            contentRect: NSRect(origin: Self.savedOrigin(size: size) ?? Self.defaultOrigin(size: size), size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        // Every Space, including over full-screen apps, where the menu bar is hidden.
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false

        let mouse = PetMouseView(frame: NSRect(origin: .zero, size: size))
        mouse.onDragEnd = { origin in
            UserDefaults.standard.set([origin.x, origin.y], forKey: Self.originKey)
        }
        let host = NSHostingView(rootView: PetView(timer: timer, sprites: sprites))
        host.frame = mouse.bounds
        host.autoresizingMask = [.width, .height]
        mouse.addSubview(host)
        panel.contentView = mouse

        panel.orderFrontRegardless()
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
    var onDragEnd: (NSPoint) -> Void = { _ in }

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
}

struct PetView: View {
    @ObservedObject var timer: PomodoroTimer
    @ObservedObject var sprites: Sprites
    @State private var up = false

    var body: some View {
        let state = PetState(timer: timer)
        Group {
            if let image = sprites.image(for: state) {
                Image(nsImage: image).resizable().scaledToFit()
            } else {
                TomatoView(state: state)
            }
        }
        .frame(width: PetController.width, height: PetController.width)
        .offset(y: up ? -PetController.bob : PetController.bob)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { up = true }
        }
    }
}
