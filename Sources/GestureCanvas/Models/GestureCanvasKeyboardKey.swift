#if os(iOS)
import UIKit

public enum GestureCanvasKeyboardKey: CaseIterable {
    case delete
    case upArrow
    case downArrow
    case leftArrow
    case rightArrow

    var input: String {
        switch self {
        case .delete: UIKeyCommand.inputDelete
        case .upArrow: UIKeyCommand.inputUpArrow
        case .downArrow: UIKeyCommand.inputDownArrow
        case .leftArrow: UIKeyCommand.inputLeftArrow
        case .rightArrow: UIKeyCommand.inputRightArrow
        }
    }
}
#endif
