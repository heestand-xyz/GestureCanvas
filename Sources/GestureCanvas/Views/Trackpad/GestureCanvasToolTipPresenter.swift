#if os(macOS)
import AppKit

/// Uses AppKit's delay and dismissal. No timer, overlay, or per-element tracking areas.
@MainActor
final class GestureCanvasToolTipPresenter: NSObject {
    private weak var view: NSView?
    private weak var canvas: GestureCanvas?
    private var tag: NSView.ToolTipTag?

    init(view: NSView, canvas: GestureCanvas) {
        self.view = view
        self.canvas = canvas
    }

    func update() {
        guard let view else { return }
        if let tag { view.removeToolTip(tag) }
        tag = nil
        guard let tip = canvas?.toolTip else { return }
        let frame = view.isFlipped ? tip.frame : CGRect(
            x: tip.frame.minX, y: view.bounds.height - tip.frame.maxY,
            width: tip.frame.width, height: tip.frame.height
        )
        let clipped = frame.intersection(view.bounds)
        guard !clipped.isNull, !clipped.isEmpty else { return }
        tag = view.addToolTip(clipped, owner: self, userData: nil)
    }

    @objc func view(_ view: NSView, stringForToolTip tag: NSView.ToolTipTag,
                    point: NSPoint, userData: UnsafeMutableRawPointer?) -> String {
        guard self.tag == tag, let canvas,
              !canvas.isPanning, !canvas.isZooming, !canvas.isInteractionDragging,
              view.window?.isKeyWindow == true else { return "" }
        return canvas.toolTip?.text() ?? ""
    }
}
#endif
