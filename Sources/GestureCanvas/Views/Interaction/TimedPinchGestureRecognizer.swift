////
////  TimedPinchGestureRecognizer.swift
////  GestureCanvas
////
////  Created by Anton Heestand on 2025-04-13.
////
//
//#if !os(macOS)
//
//import UIKit
//
//class TimedPinchGestureRecognizer: UIPinchGestureRecognizer {
//
//    private var firstTouchTimestamp: TimeInterval?
//    var maximumTouchInterval: TimeInterval = 0.2
//
//    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
//        if let touch = touches.first {
//            let timestamp = touch.timestamp
//            if numberOfTouches == 0 {
//                firstTouchTimestamp = timestamp
//            } else if let first = firstTouchTimestamp {
//                let delta = timestamp - first
//                if delta > maximumTouchInterval {
//                    self.state = .failed
//                    return
//                }
//            }
//        }
//        super.touchesBegan(touches, with: event)
//    }
//
//    override func reset() {
//        super.reset()
//        firstTouchTimestamp = nil
//    }
//}
//
//#endif
