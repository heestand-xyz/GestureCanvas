#if os(iOS)
import UIKit

/// Optional keyboard editing support for the native canvas responder.
@MainActor
public protocol GestureCanvasKeyboardDelegate: AnyObject {
    /// The shortcuts this canvas can handle. Availability is checked separately.
    func gestureCanvasKeyCommands(_ canvas: GestureCanvas) -> [GestureCanvasKeyCommand]
    func gestureCanvasCanPerformKeyCommand(_ canvas: GestureCanvas, key: GestureCanvasKeyboardKey, modifiers: Set<GestureCanvasKeyboardFlag>) -> Bool
    func gestureCanvasPerformKeyCommand(_ canvas: GestureCanvas, key: GestureCanvasKeyboardKey, modifiers: Set<GestureCanvasKeyboardFlag>)
}

extension GestureCanvasKeyboardDelegate {
    /// Preserve the built-in editing shortcuts for delegates without a custom list.
    public func gestureCanvasKeyCommands(_ canvas: GestureCanvas) -> [GestureCanvasKeyCommand] {
        let keys: [GestureCanvasKeyboardKey] = [.delete, .upArrow, .downArrow, .leftArrow, .rightArrow]
        return keys.flatMap { key in
            [Set<GestureCanvasKeyboardFlag>(), [.shift]].map { modifiers in
                GestureCanvasKeyCommand(key: key, modifiers: modifiers)
            }
        }
    }
}

// MARK: - Keyboard Focus

extension GestureCanvas {
    /// Call when a canvas selection should receive subsequent keyboard input.
    public func focusForKeyboardInput() {
        keyboardResponder?.becomeFirstResponder()
    }
}
#endif
