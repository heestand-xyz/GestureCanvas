import CoreGraphics

extension GestureCanvas {
    /// New gestures pick up exactly where an interrupted return is displayed.
    var gestureStartCoordinate: GestureCanvasCoordinate {
        boundsController == nil ? coordinate.unlimited : coordinate.limited
    }

    func updateBounds(_ bounds: CGRect?, viewportSize: CGSize) {
        if let bounds {
            if let boundsController {
                boundsController.update(contentBounds: bounds)
            } else {
                boundsController = GestureCanvasBoundsController(canvas: self, contentBounds: bounds)
            }
            boundsController?.update(viewportSize: viewportSize)
        } else {
            if boundsController != nil { gestureStart() }
            boundsController = nil
        }
    }
}
