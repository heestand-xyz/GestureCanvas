//
//  GestureCanvasInteractionView.swift
//  GestureCanvas
//
//  Created by Anton on 2024-09-08.
//

#if !os(macOS)

import UIKit
import Combine
import CoreGraphicsExtensions

final class GestureCanvasInteractionUIView: UIView {
    
    override var canBecomeFirstResponder: Bool { true }
    override var canResignFirstResponder: Bool { true }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            _ = becomeFirstResponder()
        }
    }
    
    private var interaction: UIEditMenuInteraction?
    
    private var longPressGestureRecognizer: UILongPressGestureRecognizer?
    private var panGestureRecognizer: UIPanGestureRecognizer?
    private var pinchGestureRecognizer: UIPinchGestureRecognizer?
    
    let canvas: GestureCanvas
    
    let contentView: UIView
    
    private var cancelBag: Set<AnyCancellable> = []
    
    struct Pinch {
        let location: CGPoint
        let coordinate: GestureCanvasCoordinate
    }
    private var startPinch: Pinch?

    struct Pan {
        let location: CGPoint
        let coordinate: GestureCanvasCoordinate
    }
    private var startPan: Pan?
    
    // MARK: - Init -

    public init(canvas: GestureCanvas, contentView: UIView) {
    
        self.canvas = canvas
        self.contentView = contentView
    
        super.init(frame: .zero)
        
        setup()
        layout()
        addGestures()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setup() {
        guard let delegate: UIEditMenuInteractionDelegate = canvas.delegate?.gestureCanvasEditMenuInteractionDelegate() else { return }
        let interaction = UIEditMenuInteraction(delegate: delegate)
        addInteraction(interaction)
        self.interaction = interaction
    }
    
    // MARK: - Layout
    
    private func layout() {
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(contentView)
        
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
        ])
    }
    
    // MARK: - Gestures
    
    private func addGestures() {
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(didLongPress(_:)))
        longPress.allowedTouchTypes = [UITouch.TouchType.direct.rawValue as NSNumber]
        addGestureRecognizer(longPress)
        self.longPressGestureRecognizer = longPress
        
        let pan = UIPanGestureRecognizer(target: self, action: #selector(didPan(_:)))
        pan.allowedScrollTypesMask = .continuous
        pan.allowedTouchTypes = [
            NSNumber(value: UITouch.TouchType.indirectPointer.rawValue),
        ]
        pan.minimumNumberOfTouches = 2
        pan.delegate = self
        addGestureRecognizer(pan)
        self.panGestureRecognizer = pan
        
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(didPinch(_:)))
        pinch.allowedTouchTypes = [
            NSNumber(value: UITouch.TouchType.direct.rawValue),
            NSNumber(value: UITouch.TouchType.indirectPointer.rawValue)
        ]
        pinch.delegate = self
        addGestureRecognizer(pinch)
        self.pinchGestureRecognizer = pinch
    }
    
    @objc private func didLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }
        let location: CGPoint = recognizer.location(in: contentView)
        guard let mappedLocation: CGPoint = canvas.longPress(at: location) else { return }
        canvas.lastInteractionLocation = mappedLocation
        let configuration = UIEditMenuConfiguration(identifier: nil, sourcePoint: mappedLocation)
        interaction?.presentEditMenu(with: configuration)
    }
    
    @objc private func didPan(_ recognizer: UIPanGestureRecognizer) {
        func location() -> CGPoint {
            recognizer.location(in: self) + canvas.zoomCoordinateOffset
        }
        switch recognizer.state {
        case .possible:
            break
        case .began:
            if canvas.isZooming {
                return
            }
            startPan = Pan(
                location: location(),
                coordinate: canvas.coordinate
            )
        case .changed:
            guard let startPan: Pan else { break }
            let offset: CGPoint = location() - startPan.location
            var coordinate = canvas.coordinate
            coordinate.offset = startPan.coordinate.offset + offset
            canvas.move(to: coordinate)
        case .ended, .cancelled, .failed:
            guard startPan != nil else { return }
            startPan = nil
            canvas.isPanning = false
        @unknown default:
            break
        }
    }
    
    @objc private func didPinch(_ recognizer: UIPinchGestureRecognizer) {
        func location() -> CGPoint {
            recognizer.location(in: self) + canvas.zoomCoordinateOffset
        }
        switch recognizer.state {
        case .possible:
            break
        case .began:
            guard canvas.delegate?.gestureCanvasAllowPinch(canvas) == true else { return }
            startPinch = Pinch(
                location: location(),
                coordinate: canvas.coordinate
            )
            if canvas.isPanning {
                canvas.isPanning = false
            }
            canvas.isZooming = true
        case .changed:
            /// Avoid `numberOfTouches == 1` when releasing the pinch.
            let directTouchCount: Int = 2
            let indirectTouchCount: Int = 0
            guard [directTouchCount, indirectTouchCount].contains(recognizer.numberOfTouches) else { break }
            guard let startPinch: Pinch else { break }
            var scale: CGFloat = startPinch.coordinate.scale * recognizer.scale
            if let minimumScale = canvas.minimumScale {
                scale = max(scale, minimumScale)
            }
            if let maximumScale = canvas.maximumScale {
                scale = min(scale, maximumScale)
            }
            let magnification: CGFloat = scale / startPinch.coordinate.scale
            let offset: CGPoint = location() - startPinch.location
            let locationOffset: CGPoint = startPinch.coordinate.offset - startPinch.location
            let scaledLocationOffset: CGPoint = locationOffset * magnification
            let scaleOffset: CGPoint = scaledLocationOffset - locationOffset
            var coordinate = canvas.coordinate
            coordinate.offset = startPinch.coordinate.offset + offset + scaleOffset
            coordinate.scale = scale
            canvas.move(to: coordinate)
        case .ended, .cancelled, .failed:
            guard startPinch != nil else { return }
            startPinch = nil
            canvas.isZooming = false
        @unknown default:
            break
        }
    }
    
    // MARK: - Touches

#if os(iOS)
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        for touch in touches where touch.type == .indirectPointer {
            canvas.isIndirectTouching = true
            break
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        for touch in touches where touch.type == .indirectPointer {
            canvas.isIndirectTouching = false
            break
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        canvas.isIndirectTouching = false
    }
    
#endif
    
    // MARK: - Presses
    
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        super.pressesBegan(presses, with: event)
        if let flags: UIKeyModifierFlags = event?.modifierFlags {
            add(flags: flags)
        }
    }
    
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        super.pressesEnded(presses, with: event)
        canvas.keyboardFlags = []
    }
    
    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        super.pressesCancelled(presses, with: event)
        canvas.keyboardFlags = []
    }
    
    func add(flags: UIKeyModifierFlags) {
        if flags.contains(.command) {
            canvas.keyboardFlags.insert(.command)
        }
        if flags.contains(.control) {
            canvas.keyboardFlags.insert(.control)
        }
        if flags.contains(.shift) {
            canvas.keyboardFlags.insert(.shift)
        }
        if flags.contains(.alternate) {
            canvas.keyboardFlags.insert(.option)
        }
    }
}

extension GestureCanvasInteractionUIView: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        if gestureRecognizer == pinchGestureRecognizer {
            return true
        }
        return false
    }
}

#endif
