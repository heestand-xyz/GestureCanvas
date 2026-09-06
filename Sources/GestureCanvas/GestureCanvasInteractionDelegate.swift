import CoreGraphics

/// Routes interactions to content drawn inside a canvas, before background actions.
/// Locations use the same view coordinate space as the canvas's background delegate.
@MainActor
public protocol GestureCanvasInteractionDelegate: AnyObject {
    func gestureCanvas(_ canvas: GestureCanvas, tapAt location: CGPoint, count: Int) -> Bool
    func gestureCanvas(_ canvas: GestureCanvas, longPressAt location: CGPoint) -> Bool
    func gestureCanvas(_ canvas: GestureCanvas, contextAt location: CGPoint) -> Bool
    func gestureCanvas(_ canvas: GestureCanvas, beginDragAt location: CGPoint) -> Bool
    func gestureCanvas(_ canvas: GestureCanvas, updateDragAt location: CGPoint)
    func gestureCanvas(_ canvas: GestureCanvas, endDragAt location: CGPoint)
    func gestureCanvasCancelInteraction(_ canvas: GestureCanvas)
    func gestureCanvas(_ canvas: GestureCanvas, hoverAt location: CGPoint?)
}

public extension GestureCanvasInteractionDelegate {
    func gestureCanvas(_ canvas: GestureCanvas, contextAt location: CGPoint) -> Bool {
        false
    }
}
