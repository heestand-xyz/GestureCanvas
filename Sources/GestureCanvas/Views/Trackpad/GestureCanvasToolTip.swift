#if os(macOS)
import AppKit

/// A single help region in the canvas's top-left view coordinate system.
@MainActor
public struct GestureCanvasToolTip {
    public let id: AnyHashable
    public let frame: CGRect
    let text: @MainActor () -> String?

    public init(id: AnyHashable, frame: CGRect, text: @escaping @MainActor () -> String?) {
        self.id = id
        self.frame = frame
        self.text = text
    }
}
#endif
