import AppKit
import SwiftUI

extension View {
    /// A hover tooltip from AppKit itself. SwiftUI's `.help` shows nothing in the app window, which is an
    /// AppKit window hosting SwiftUI.
    func tooltip(_ text: String) -> some View {
        overlay(TooltipView(text: text))
    }
}

/// A see-through view that only carries the tooltip; clicks pass through to the control under it.
private struct TooltipView: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSView {
        let view = PassThroughView()
        view.toolTip = text
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        view.toolTip = text
    }

    private final class PassThroughView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
