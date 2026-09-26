#if os(iOS)
import UIKit

/// An app-provided shortcut offered while the canvas is the keyboard responder.
public struct GestureCanvasKeyCommand {
    public let key: GestureCanvasKeyboardKey
    public let modifiers: Set<GestureCanvasKeyboardFlag>
    public let title: String?

    public init(key: GestureCanvasKeyboardKey, modifiers: Set<GestureCanvasKeyboardFlag> = [], title: String? = nil) {
        self.key = key
        self.modifiers = modifiers
        self.title = title
    }

    var modifierFlags: UIKeyModifierFlags {
        var flags: UIKeyModifierFlags = []
        if modifiers.contains(.command) { flags.insert(.command) }
        if modifiers.contains(.control) { flags.insert(.control) }
        if modifiers.contains(.shift) { flags.insert(.shift) }
        if modifiers.contains(.option) { flags.insert(.alternate) }
        return flags
    }
}
#endif
