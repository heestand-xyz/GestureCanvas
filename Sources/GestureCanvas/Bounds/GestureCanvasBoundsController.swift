import CoreGraphics
import Foundation

/// Shared camera bounds; input adapters keep ownership of their gesture physics.
@MainActor
final class GestureCanvasBoundsController {
    private unowned let canvas: GestureCanvas
    private(set) var contentBounds: CGRect
    private var viewportSize: CGSize = .zero
    private var settlementTask: Task<Void, Never>?
    private var settlementSequence: UInt = 0
    private var isSettling = false

    init(canvas: GestureCanvas, contentBounds: CGRect) {
        self.canvas = canvas
        self.contentBounds = contentBounds
    }

    func update(contentBounds: CGRect) {
        // A moving folder may shrink before its final drop has committed.
        // Updating geometry must never change the displayed camera by itself.
        self.contentBounds = contentBounds
    }

    func update(viewportSize: CGSize) {
        guard self.viewportSize != viewportSize else { return }
        // Container recentering belongs to the app; invalidate pending zoom and
        // bounds returns as well as any animation that used the previous size.
        canvas.gestureStart()
        self.viewportSize = viewportSize
    }

    func refreshBounds() {
        if let bounds = canvas.delegate?.gestureCanvasBounds(canvas) {
            contentBounds = bounds
        }
    }

    func limit(_ coordinate: GestureCanvasCoordinate, withTension: Bool) -> GestureCanvasCoordinate {
        guard viewportSize.width > 0, viewportSize.height > 0 else { return coordinate }
        let geometry = GestureCanvasBoundsGeometry(contentBounds: contentBounds, scale: coordinate.scale,
                                                   viewportSize: viewportSize)
        let offset = geometry.contentOffset(for: coordinate.offset)
        let limited = withTension
            ? geometry.rubberBanded(offset, viewportSize: viewportSize)
            : geometry.clamped(offset, viewportSize: viewportSize)
        guard limited != offset else { return coordinate }
        return GestureCanvasCoordinate(offset: geometry.cameraOffset(for: limited), scale: coordinate.scale)
    }

    func cancelSettlement() {
        settlementSequence &+= 1
        settlementTask?.cancel()
        settlementTask = nil
        if isSettling {
            isSettling = false
            canvas.cancelMoveAnimation()
        }
    }

    func settleAfterInteraction() {
        guard !canvas.isPanning, !canvas.isZooming, !canvas.isInteractionDragging,
              !canvas.isCancellingInteraction else { return }
        cancelSettlement()
        let sequence = settlementSequence
        let gestureSequence = canvas.gestureSequence
        let releasedCoordinate = canvas.coordinate.limited
        settlementTask = Task(name: "GestureCanvasBoundsController: Settle Released Viewport") { [weak self, canvas] in
            await canvas.delegate?.gestureCanvasWillSettleBounds(canvas)
            guard let self, !Task.isCancelled, settlementSequence == sequence else { return }
            defer {
                if settlementSequence == sequence {
                    isSettling = false
                    settlementTask = nil
                }
            }
            guard canvas.gestureSequence == gestureSequence,
                  !canvas.isPanning, !canvas.isZooming, !canvas.isInteractionDragging,
                  !canvas.isAnimating, canvas.coordinate.limited == releasedCoordinate else { return }
            refreshBounds()
            let target = limit(releasedCoordinate, withTension: false)
            guard target != releasedCoordinate else { return }
            isSettling = true
            await canvas.animateGesture(to: target, sequence: gestureSequence)
        }
    }
}
