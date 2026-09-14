//
//  GestureCanvasTapGestureRecognizer.swift
//  GestureCanvas
//

#if canImport(UIKit)

import UIKit

final class GestureCanvasTapGestureRecognizer: UITapGestureRecognizer {
    private let canvas: GestureCanvas
    private var hasCapturedKeyboardFlags = false
    private(set) var keyboardFlags: Set<GestureCanvasKeyboardFlag> = []

    init(canvas: GestureCanvas, target: Any?, action: Selector?) {
        self.canvas = canvas
        super.init(target: target, action: action)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        // Each recognizer owns its snapshot, including while it waits for another
        // recognizer to fail. An empty snapshot is still a captured value.
        if !hasCapturedKeyboardFlags {
            keyboardFlags = canvas.keyboardFlags
            hasCapturedKeyboardFlags = true
        }
        super.touchesBegan(touches, with: event)
    }

    override func reset() {
        super.reset()
        hasCapturedKeyboardFlags = false
        keyboardFlags = []
    }
}

#endif
