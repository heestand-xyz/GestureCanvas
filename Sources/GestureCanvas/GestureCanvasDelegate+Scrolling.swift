import CoreGraphics

public extension GestureCanvasDelegate {
    func gestureCanvasBounds(_ canvas: GestureCanvas) -> CGRect? { nil }

    func gestureCanvasWillSettleBounds(_ canvas: GestureCanvas) async {}

#if !os(macOS)
    func gestureCanvasUsesNativeScrolling(_ canvas: GestureCanvas) -> Bool { false }
#endif
}
