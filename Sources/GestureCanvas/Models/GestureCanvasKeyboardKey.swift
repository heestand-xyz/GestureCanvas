#if os(iOS)
import UIKit

public enum GestureCanvasKeyboardKey: Hashable {
    case character(Character)
    case delete
    case escape
    case `return`
    case space
    case upArrow
    case downArrow
    case leftArrow
    case rightArrow

    var input: String {
        switch self {
        case .character(let character): String(character).lowercased()
        case .delete: UIKeyCommand.inputDelete
        case .escape: UIKeyCommand.inputEscape
        case .return: "\r"
        case .space: " "
        case .upArrow: UIKeyCommand.inputUpArrow
        case .downArrow: UIKeyCommand.inputDownArrow
        case .leftArrow: UIKeyCommand.inputLeftArrow
        case .rightArrow: UIKeyCommand.inputRightArrow
        }
    }
}
#endif
