#if !os(macOS)

import UIKit
import CoreGraphicsExtensions

/// Observes physical contacts without recognizing or competing with editing,
/// scrolling, tap, long-press, or zoom gestures.
final class GestureCanvasBackgroundPressGestureRecognizer: UIGestureRecognizer, GestureCanvasBackgroundPressObserver {
    private let canvas: GestureCanvas
    private unowned let contentView: UIView
    private var backgroundTouches: Set<ObjectIdentifier> = []
    private var activeTouches: Set<ObjectIdentifier> = []

    init(canvas: GestureCanvas, contentView: UIView) {
        self.canvas = canvas
        self.contentView = contentView
        super.init(target: nil, action: nil)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }
    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        for touch in touches {
            let id = ObjectIdentifier(touch)
            activeTouches.insert(id)
            let point = touch.location(in: contentView)
            guard contentView.bounds.contains(point),
                  canvas.allowsBackgroundPress(at: point + canvas.zoomCoordinateOffset) else { continue }
            backgroundTouches.insert(id)
        }
        canvas.updateBackgroundPress(!backgroundTouches.isEmpty)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {}

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        finish(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        finish(touches)
    }

    override func reset() {
        super.reset()
        cancelBackgroundPressTracking()
    }

    func cancelBackgroundPressTracking() {
        backgroundTouches.removeAll()
        activeTouches.removeAll()
        canvas.updateBackgroundPress(false)
    }

    private func finish(_ touches: Set<UITouch>) {
        for touch in touches {
            let id = ObjectIdentifier(touch)
            backgroundTouches.remove(id)
            activeTouches.remove(id)
        }
        canvas.updateBackgroundPress(!backgroundTouches.isEmpty)
        if activeTouches.isEmpty { state = .failed }
    }
}

#endif
