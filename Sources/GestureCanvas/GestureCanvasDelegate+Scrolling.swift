#if !os(macOS)

import CoreGraphics

public extension GestureCanvasDelegate {
    func gestureCanvasScrollBounds(_ canvas: GestureCanvas) -> CGRect? { nil }

    func gestureCanvasWillSettleScrollBounds(_ canvas: GestureCanvas) async {}
}

#endif
