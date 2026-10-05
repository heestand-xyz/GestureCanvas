import CoreGraphics

/// Routes interactions to content drawn inside a canvas, before background actions.
/// Locations use the hosted content's view coordinate space plus `zoomCoordinateOffset`,
/// matching the background delegate. The hosting view already accounts for safe-area insets.
///
/// Drags are keyed by `GestureCanvasDragID` since touch canvases run one drag per touch.
@MainActor
public protocol GestureCanvasInteractionDelegate: AnyObject {
    /// Keyboard flags are captured at press start, before tap recognition can be delayed.
    func gestureCanvas(_ canvas: GestureCanvas, tapAt location: CGPoint, count: Int,
                       keyboardFlags: Set<GestureCanvasKeyboardFlag>) -> Bool
    func gestureCanvas(_ canvas: GestureCanvas, longPressAt location: CGPoint) -> Bool
    func gestureCanvas(_ canvas: GestureCanvas, contextAt location: CGPoint) -> Bool
    /// Asked on touch down, before any movement, to tell content touches from background touches.
    func gestureCanvas(_ canvas: GestureCanvas, hasContentAt location: CGPoint) -> Bool
    /// Opt in to immediate background contact reporting, before a pan begins.
    func gestureCanvasTracksBackgroundPresses(_ canvas: GestureCanvas) -> Bool
    func gestureCanvasBackgroundPressChanged(_ canvas: GestureCanvas, isPressed: Bool)
    func gestureCanvas(_ canvas: GestureCanvas, beginDrag id: GestureCanvasDragID, at location: CGPoint) -> Bool
    /// Called when the pointer moves or the canvas coordinate changes during a drag.
    /// A stationary pointer keeps its last view-space location as the canvas pans.
    func gestureCanvas(_ canvas: GestureCanvas, updateDrag id: GestureCanvasDragID, at location: CGPoint)
    func gestureCanvas(_ canvas: GestureCanvas, endDrag id: GestureCanvasDragID, at location: CGPoint)
    func gestureCanvas(_ canvas: GestureCanvas, cancelDrag id: GestureCanvasDragID)
    func gestureCanvasCancelInteraction(_ canvas: GestureCanvas)
    func gestureCanvas(_ canvas: GestureCanvas, hoverAt location: CGPoint?)
}

public extension GestureCanvasInteractionDelegate {
    func gestureCanvasTracksBackgroundPresses(_ canvas: GestureCanvas) -> Bool { false }
    func gestureCanvasBackgroundPressChanged(_ canvas: GestureCanvas, isPressed: Bool) {}

    func gestureCanvas(_ canvas: GestureCanvas, contextAt location: CGPoint) -> Bool {
        false
    }
}
