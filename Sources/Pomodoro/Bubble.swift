import AppKit
import SwiftUI

/// "Focus done! Break next" beside the pet while the alarm rings, with a Stop button. It records nothing.
@MainActor
final class BubbleController {
    private let panel: NSPanel

    init(timer: PomodoroTimer) {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        // Above the popout, in case they meet at a screen edge.
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 2)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.contentView = FirstMouseHostingView(rootView: BubbleView(timer: timer))
    }

    func show(pet: NSRect, popout: NSRect?) {
        if let content = panel.contentView { panel.setContentSize(content.fittingSize) }
        place(pet: pet, popout: popout)
        panel.orderFrontRegardless()
        panel.invalidateShadow()
    }

    func hide() {
        panel.orderOut(nil)
    }

    /// Beside the pet, or stacked on the popout while it's open, since both want the side with room.
    func place(pet: NSRect, popout: NSRect?) {
        let size = panel.frame.size
        panel.setFrameOrigin(popout.map { Placement.stacked(on: $0, pet: pet, size: size) } ?? Placement.beside(pet, size: size))
    }
}

struct BubbleView: View {
    @ObservedObject var timer: PomodoroTimer

    var body: some View {
        // The timer holds on the phase that just finished until Reset.
        HStack(spacing: 10) {
            Text("\(timer.phase.label) done! \(timer.phase.other.label) next")
            Button("Stop") { timer.stopAlarm() }
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .fixedSize()
        .background(VisualEffectBackground())
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
