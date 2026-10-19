import AppKit

/// Where the pet's panels sit: beside the pet on the side with more room, clamped to its screen.
enum Placement {
    static let gap: CGFloat = 8
    static let margin: CGFloat = 8

    /// Beside `anchor` and centred on it, on whichever side of its screen has more room.
    static func beside(_ anchor: NSRect, size: NSSize) -> NSPoint {
        let screen = visibleFrame(around: anchor)
        let onLeft = anchor.midX > screen.midX
        let x = onLeft ? anchor.minX - gap - size.width : anchor.maxX + gap
        return clamped(NSPoint(x: x, y: anchor.midY - size.height / 2), size: size, in: screen)
    }

    /// The visible frame of the screen under the rect's centre.
    private static func visibleFrame(around rect: NSRect) -> NSRect {
        let center = NSPoint(x: rect.midX, y: rect.midY)
        return (NSScreen.screens.first { $0.frame.contains(center) } ?? NSScreen.main ?? NSScreen.screens[0]).visibleFrame
    }

    private static func clamped(_ origin: NSPoint, size: NSSize, in screen: NSRect) -> NSPoint {
        NSPoint(x: min(max(origin.x, screen.minX + margin), screen.maxX - size.width - margin),
                y: min(max(origin.y, screen.minY + margin), screen.maxY - size.height - margin))
    }
}
