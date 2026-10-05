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
    private var contentTouches: [ObjectIdentifier: GestureCanvasDragID] = [:]

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
            guard contentView.bounds.contains(point) else { continue }
            let location = point + canvas.zoomCoordinateOffset
            contentTouches[id] = canvas.beginContentPress(at: location)
            guard canvas.allowsBackgroundPress(at: location) else { continue }
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
        for id in contentTouches.values { canvas.endContentPress(id) }
        contentTouches.removeAll()
        backgroundTouches.removeAll()
        activeTouches.removeAll()
        canvas.updateBackgroundPress(false)
    }

    private func finish(_ touches: Set<UITouch>) {
        for touch in touches {
            let id = ObjectIdentifier(touch)
            canvas.endContentPress(contentTouches.removeValue(forKey: id))
            backgroundTouches.remove(id)
            activeTouches.remove(id)
        }
        canvas.updateBackgroundPress(!backgroundTouches.isEmpty)
        if activeTouches.isEmpty { state = .failed }
    }
}

#endif
