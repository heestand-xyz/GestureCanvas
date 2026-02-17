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
    
    /// **Tap**.
    private var tapGestureRecognizer: UITapGestureRecognizer?
    /// **Long press** to present edit menu.
    private var longPressGestureRecognizer: UILongPressGestureRecognizer?
    /// **Pan** on trackpad.
    private var panGestureRecognizer: UIPanGestureRecognizer?
    /// **Pinch** to zoom.
    private var pinchGestureRecognizer: UIPinchGestureRecognizer?
    /// Double **tap** and pan to zoom.
    private var doubleTapGestureRecognizer: UITapGestureRecognizer?
    /// **Double tap and drag** to zoom.
    private var doubleTapDragGestureRecognizer: DoubleTapDragGestureRecognizer?

    let canvas: GestureCanvas
    
    let contentView: UIView
    
    private var cancelBag: Set<AnyCancellable> = []
    
    struct Zoom {
        let location: CGPoint
        let coordinate: GestureCanvasCoordinate
    }
    private var startZoom: Zoom?
    /// `0` or `2` touches, not `1`.
    private var lastPinchZoomLocation: CGPoint?

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
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTap(_:)))
        tap.numberOfTapsRequired = 1
        tap.delegate = self
        addGestureRecognizer(tap)
        self.tapGestureRecognizer = tap
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(didLongPress(_:)))
        longPress.allowedTouchTypes = [
            UITouch.TouchType.direct.rawValue as NSNumber,
        ]
        addGestureRecognizer(longPress)
        self.longPressGestureRecognizer = longPress
        
        let pan = UIPanGestureRecognizer(target: self, action: #selector(didPan(_:)))
        pan.allowedScrollTypesMask = .continuous
        pan.allowedTouchTypes = [
            UITouch.TouchType.indirectPointer.rawValue as NSNumber,
        ]
        pan.minimumNumberOfTouches = 2
        pan.delegate = self
        addGestureRecognizer(pan)
        self.panGestureRecognizer = pan
        
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(didPinch(_:)))
        pinch.allowedTouchTypes = [
            UITouch.TouchType.direct.rawValue as NSNumber,
            UITouch.TouchType.indirectPointer.rawValue as NSNumber,
        ]
        pinch.delegate = self
        addGestureRecognizer(pinch)
        self.pinchGestureRecognizer = pinch
        
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(didDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        doubleTap.delegate = self
        addGestureRecognizer(doubleTap)
        self.doubleTapGestureRecognizer = doubleTap
        
        let doubleTapDrag = DoubleTapDragGestureRecognizer(target: self, action: #selector(didDoubleTapDrag(_:)))
        doubleTapDrag.delegate = self
        addGestureRecognizer(doubleTapDrag)
        doubleTapDragGestureRecognizer = doubleTapDrag

        tap.require(toFail: doubleTapDrag)
        doubleTap.require(toFail: doubleTapDrag)
        longPress.require(toFail: doubleTapDrag)
        tap.require(toFail: doubleTap)
    }
    
    @objc private func didTap(_ recognizer: UITapGestureRecognizer) {
        if recognizer.state == .ended {
            let location: CGPoint = recognizer.location(in: self) + canvas.zoomCoordinateOffset
            canvas.backgroundTap(at: location)
        }
    }
    
    @objc private func didLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }
        let location: CGPoint = recognizer.location(in: self) + canvas.zoomCoordinateOffset
        guard canvas.longPress(at: location) else { return }
        canvas.lastInteractionLocation = location
        let configuration = UIEditMenuConfiguration(identifier: nil, sourcePoint: location)
        interaction?.presentEditMenu(with: configuration)
    }
    
    @objc private func didPan(_ recognizer: UIPanGestureRecognizer) {
        let location: CGPoint = recognizer.location(in: self) + canvas.zoomCoordinateOffset
        switch recognizer.state {
        case .possible:
            break
        case .began:
            if canvas.isZooming {
                return
            }
            startPan = Pan(
                location: location,
                coordinate: canvas.coordinate.unlimited
            )
            canvas.startPan(at: location)
            canvas.gestureStart()
        case .changed:
            guard let startPan: Pan else { break }
            let offset: CGPoint = location - startPan.location
            var coordinate = canvas.coordinate.unlimited
            coordinate.offset = startPan.coordinate.offset + offset
            canvas.gestureUpdate(to: coordinate, at: location)
            canvas.updatePan(at: location)
        case .ended, .cancelled, .failed:
            guard startPan != nil else { return }
            startPan = nil
            Task {
                await canvas.gestureEnded(at: location)
                canvas.endPan(at: location)
            }
        @unknown default:
            break
        }
    }
    
    @objc private func didPinch(_ recognizer: UIPinchGestureRecognizer) {
        let location: CGPoint = recognizer.location(in: self) + canvas.zoomCoordinateOffset
        switch recognizer.state {
        case .possible:
            break
        case .began:
            guard canvas.delegate?.gestureCanvasAllowPinch(canvas) == true else { return }
            startZoom = Zoom(
                location: location,
                coordinate: canvas.coordinate.unlimited
            )
            if canvas.isPanning {
                canvas.cancelPan()
            }
            canvas.startZoom(at: location)
            canvas.gestureStart()
        case .changed:
            /// Avoid `numberOfTouches == 1` when releasing the pinch.
            let directTouchCount: Int = 2
            let indirectTouchCount: Int = 0
            guard [directTouchCount, indirectTouchCount].contains(recognizer.numberOfTouches) else { break }
            guard let startZoom: Zoom else { break }
            var scale: CGFloat = startZoom.coordinate.scale * recognizer.scale
            if let minimumScale = canvas.minimumScale {
                scale = max(scale, minimumScale)
            }
            if let maximumScale = canvas.maximumScale {
                scale = min(scale, maximumScale)
            }
            let magnification: CGFloat = scale / startZoom.coordinate.scale
            let offset: CGPoint = location - startZoom.location
            let locationOffset: CGPoint = startZoom.coordinate.offset - startZoom.location
            let scaledLocationOffset: CGPoint = locationOffset * magnification
            let scaleOffset: CGPoint = scaledLocationOffset - locationOffset
            let coordinate = GestureCanvasCoordinate(
                offset: startZoom.coordinate.offset + offset + scaleOffset,
                scale: scale
            )
            canvas.gestureUpdate(to: coordinate, at: location)
            canvas.updateZoom(at: location)
            lastPinchZoomLocation = location
        case .ended, .cancelled, .failed:
            guard startZoom != nil else { return }
            startZoom = nil
            let lastLocation: CGPoint = lastPinchZoomLocation ?? location
            lastPinchZoomLocation = nil
            canvas.willEndZoom(at: lastLocation)
            Task {
                await canvas.gestureEnded(at: lastLocation)
                canvas.didEndZoom(at: lastLocation)
            }
        @unknown default:
            break
        }
    }
    
    @objc private func didDoubleTap(_ recognizer: UITapGestureRecognizer) {
        if recognizer.state == .ended {
            let location: CGPoint = recognizer.location(in: self) + canvas.zoomCoordinateOffset
            canvas.backgroundDoubleTap(at: location)
        }
    }
    
    @objc private func didDoubleTapDrag(_ recognizer: DoubleTapDragGestureRecognizer) {
        let location: CGPoint = recognizer.location(in: self) + canvas.zoomCoordinateOffset
        switch recognizer.state {
        case .possible:
            break
        case .began:
            startZoom = Zoom(
                location: location,
                coordinate: canvas.coordinate.unlimited
            )
            if canvas.isPanning {
                canvas.cancelPan()
            }
            canvas.startZoom(at: location)
            canvas.gestureStart()
        case .changed:
            guard let startZoom: Zoom else { break }
            let dy = recognizer.translation.y
            let factor = exp(-dy * 0.005)
            var scale = startZoom.coordinate.scale * factor
            if let minimumScale = canvas.minimumScale {
                scale = max(scale, minimumScale)
            }
            if let maximumScale = canvas.maximumScale {
                scale = min(scale, maximumScale)
            }
            let magnification: CGFloat = scale / startZoom.coordinate.scale
            let offset: CGPoint = .zero
            let locationOffset: CGPoint = startZoom.coordinate.offset - startZoom.location
            let scaledLocationOffset: CGPoint = locationOffset * magnification
            let scaleOffset: CGPoint = scaledLocationOffset - locationOffset
            let coordinate = GestureCanvasCoordinate(
                offset: startZoom.coordinate.offset + offset + scaleOffset,
                scale: scale
            )
            canvas.gestureUpdate(to: coordinate, at: startZoom.location)
            canvas.updateZoom(at: startZoom.location)
        case .ended, .cancelled, .failed:
            guard let startZoom: Zoom else { return }
            self.startZoom = nil
            canvas.willEndZoom(at: startZoom.location)
            Task {
                await canvas.gestureEnded(at: startZoom.location)
                canvas.didEndZoom(at: startZoom.location)
            }
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
//        if gestureRecognizer == doublePanGestureRecognizer {
//            return true
//        }
        if gestureRecognizer == pinchGestureRecognizer {
            return otherGestureRecognizer != doubleTapDragGestureRecognizer
        }
        return false
    }
}

#endif
