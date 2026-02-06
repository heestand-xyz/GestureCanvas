//
//  DoubleTapDragGestureRecognizer.swift
//  GestureCanvas
//
//  Created by Anton Heestand with AI on 2026-02-06.
//

#if canImport(UIKit)

import UIKit

final class DoubleTapDragGestureRecognizer: UIGestureRecognizer {

    var maxInterTapInterval: TimeInterval = 0.35
    var maxTapMovement: CGFloat = 12
    var dragStartThreshold: CGFloat = 6

    private var hasBegunDrag = false
    private var tapCount = 0
    private var firstTapTime: TimeInterval = 0
    private var firstTapPoint: CGPoint = .zero
    private var secondTapStartPoint: CGPoint = .zero
    private(set) var translation: CGPoint = .zero
    
    private var failWorkItem: DispatchWorkItem?
    
    override func reset() {
        super.reset()
        failWorkItem?.cancel()
        failWorkItem = nil
        tapCount = 0
        firstTapTime = 0
        firstTapPoint = .zero
        secondTapStartPoint = .zero
        translation = .zero
        hasBegunDrag = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if (event.allTouches?.count ?? touches.count) > 1 {
            state = .failed
            return
        }
        guard touches.count == 1, let t = touches.first, let v = view else {
            state = .failed
            return
        }

        let p = t.location(in: v)
        let now = t.timestamp

        if tapCount == 0 {
            tapCount = 1
            firstTapTime = now
            firstTapPoint = p
            state = .possible
            return
        }

        // second tap
        failWorkItem?.cancel()
        failWorkItem = nil

        if now - firstTapTime > maxInterTapInterval {
            state = .failed
            return
        }

        tapCount = 2
        secondTapStartPoint = p
        translation = .zero
        hasBegunDrag = false
        state = .possible
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let t = touches.first, let v = view else { return }
        let p = t.location(in: v)

        if tapCount == 1 {
            // movement during first tap invalidates it as a tap
            if hypot(p.x - firstTapPoint.x, p.y - firstTapPoint.y) > maxTapMovement {
                state = .failed
            }
            return
        }

        let dx = p.x - secondTapStartPoint.x
        let dy = p.y - secondTapStartPoint.y
        let dist = hypot(dx, dy)

        if !hasBegunDrag {
            guard dist >= dragStartThreshold else { return }
            hasBegunDrag = true
            translation = .zero
            state = .began
        }

        translation = CGPoint(x: dx, y: dy)
        state = .changed
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        if tapCount == 2 {
            state = hasBegunDrag ? .ended : .failed
            return
        }

        // first tap ended; wait briefly for the second tap, then fail so single-tap can fire normally
        failWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if self.state == .possible && self.tapCount == 1 {
                self.state = .failed
            }
        }
        failWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + maxInterTapInterval, execute: item)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .cancelled
    }
}

#endif
