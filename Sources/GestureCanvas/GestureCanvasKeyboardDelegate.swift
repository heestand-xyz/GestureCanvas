#if os(iOS)
import UIKit

/// Optional keyboard editing support for the native canvas responder.
@MainActor
public protocol GestureCanvasKeyboardDelegate: AnyObject {
    func gestureCanvasCanPerformKeyCommand(_ canvas: GestureCanvas, key: GestureCanvasKeyboardKey, modifiers: Set<GestureCanvasKeyboardFlag>) -> Bool
    func gestureCanvasPerformKeyCommand(_ canvas: GestureCanvas, key: GestureCanvasKeyboardKey, modifiers: Set<GestureCanvasKeyboardFlag>)
}

extension GestureCanvas {
    /// Call when a canvas selection should receive subsequent keyboard input.
    public func focusForKeyboardInput() {
        keyboardResponder?.becomeFirstResponder()
    }
}
#endif
