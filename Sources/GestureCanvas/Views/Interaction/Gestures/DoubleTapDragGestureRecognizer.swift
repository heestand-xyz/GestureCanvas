//
//  DoubleTapDragGestureRecognizer.swift
//  GestureCanvas
//
//  Created by Anton Heestand with AI on 2026-02-06.
//

#if canImport(UIKit)

import UIKit

final class DoubleTapDragGestureRecognizer: UIGestureRecognizer {

    var maxTapDownInterval: TimeInterval = 0.35
    var maxTapUpInterval: TimeInterval = 0.35
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
            // First
            tapCount = 1
            firstTapTime = now
            firstTapPoint = p
            state = .possible
            let item = DispatchWorkItem { [weak self] in
                guard let self else { return }
                if self.state == .possible && self.tapCount == 1 {
                    self.state = .failed
                }
            }
            failWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + maxTapDownInterval, execute: item)
        } else {
            // Second
            failWorkItem?.cancel()
            failWorkItem = nil
            
            if (now - firstTapTime) > (maxTapDownInterval + maxTapUpInterval) {
                state = .failed
                return
            }
            
            tapCount = 2
            secondTapStartPoint = p
            translation = .zero
            hasBegunDrag = false
            state = .possible
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let t = touches.first, let v = view else { return }
        let p = t.location(in: v)

        if tapCount == 1 {
            // First
            if hypot(p.x - firstTapPoint.x, p.y - firstTapPoint.y) > maxTapMovement {
                state = .failed
            }
            return
        } else {
            // Second
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
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        if tapCount == 1 {
            // First
            failWorkItem?.cancel()
            let item = DispatchWorkItem { [weak self] in
                guard let self else { return }
                if self.state == .possible && self.tapCount == 1 {
                    self.state = .failed
                }
            }
            failWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + maxTapUpInterval, execute: item)
        } else {
            // Second
            state = hasBegunDrag ? .ended : .failed
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .cancelled
    }
}

#endif
