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

final class GestureCanvasInteractionUIView: UIView, GestureCanvasInteractionHost {

    var gestureCanvasInteractionView: UIView { self }
    
    override var canBecomeFirstResponder: Bool { true }
    override var canResignFirstResponder: Bool { true }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
#if os(iOS)
            canvas.keyboardResponder = self
#endif
            _ = becomeFirstResponder()
        } else {
#if os(iOS)
            if canvas.keyboardResponder === self {
                canvas.keyboardResponder = nil
            }
#endif
            canvas.cancelInteraction()
        }
    }

    override func resignFirstResponder() -> Bool {
        let didResign = super.resignFirstResponder()
        if didResign {
            canvas.cancelInteraction()
        }
        return didResign
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
    /// Pointer hover on supported devices.
    private var hoverGestureRecognizer: UIHoverGestureRecognizer?
    /// **Drag** per touch, for canvases that route interactions.
    private var multiDragGestureRecognizer: GestureCanvasMultiDragGestureRecognizer?

    private var scrollController: GestureCanvasScrollController?
    private var zoomSequence: UInt = 0

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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func applicationWillResignActive() {
        canvas.cancelInteraction()
    }
    
    // MARK: - Setup
    
    private func setup() {
        guard let delegate: UIEditMenuInteractionDelegate = canvas.delegate?.gestureCanvasEditMenuInteractionDelegate(canvas) else { return }
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

    override func layoutSubviews() {
        super.layoutSubviews()
        scrollController?.layout(in: contentView.frame)
    }

    func updateScrollBounds(_ bounds: CGRect?) {
        if let bounds {
            if let scrollController {
                scrollController.update(contentBounds: bounds)
                return
            }
            let controller = GestureCanvasScrollController(canvas: canvas, contentView: contentView, contentBounds: bounds)
            insertSubview(controller.scrollView, belowSubview: contentView)
            // Keep UIKit's pan delegate. Our parent recognizers arbitrate with it.
            if let doubleTapDragGestureRecognizer {
                controller.scrollView.panGestureRecognizer.require(toFail: doubleTapDragGestureRecognizer)
            }
            scrollController = controller
            canvas.scrollController = controller
            multiDragGestureRecognizer?.scrollView = controller.scrollView
            panGestureRecognizer?.isEnabled = false
        } else {
            scrollController?.detach()
            scrollController = nil
            multiDragGestureRecognizer?.scrollView = nil
            panGestureRecognizer?.isEnabled = true
        }
        setNeedsLayout()
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        guard hit != nil, let scrollController else { return hit }
        let location = convert(point, to: contentView) + canvas.zoomCoordinateOffset
        guard contentView.bounds.contains(convert(point, to: contentView)),
              !canvas.isDragExcluded(at: location) else { return hit }
        // Trackpad scrolling can begin over a node. Pointer click-drags continue
        // through the hosted view for selection and object dragging in this session.
        if event?.type == .scroll {
            return scrollController.scrollView
        }
        guard event?.type == .touches,
              event?.buttonMask.isEmpty != false,
              event?.allTouches?.contains(where: { $0.type == .indirectPointer }) != true,
              !canvas.interactionHasContent(at: location) else { return hit }
        return scrollController.scrollView
    }
    
    // MARK: - Gestures
    
    private func addGestures() {
        
        let tap = GestureCanvasTapGestureRecognizer(canvas: canvas, target: self, action: #selector(didTap(_:)))
        tap.numberOfTapsRequired = 1
        tap.delegate = self
        addGestureRecognizer(tap)
        self.tapGestureRecognizer = tap
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(didLongPress(_:)))
#if os(iOS)
        longPress.allowedTouchTypes = [
            UITouch.TouchType.direct.rawValue as NSNumber,
        ]
#endif
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
        
        let doubleTap = GestureCanvasTapGestureRecognizer(canvas: canvas, target: self, action: #selector(didDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        doubleTap.delegate = self
        addGestureRecognizer(doubleTap)
        self.doubleTapGestureRecognizer = doubleTap
        
        let doubleTapDrag = DoubleTapDragGestureRecognizer(target: self, action: #selector(didDoubleTapDrag(_:)))
        doubleTapDrag.delegate = self
        addGestureRecognizer(doubleTapDrag)
        doubleTapDragGestureRecognizer = doubleTapDrag

        let hover = UIHoverGestureRecognizer(target: self, action: #selector(didHover(_:)))
        hover.cancelsTouchesInView = false
        hover.delegate = self
        addGestureRecognizer(hover)
        hoverGestureRecognizer = hover

        let multiDrag = GestureCanvasMultiDragGestureRecognizer(canvas: canvas, contentView: contentView)
        multiDrag.delegate = self
        addGestureRecognizer(multiDrag)
        multiDragGestureRecognizer = multiDrag

        tap.require(toFail: doubleTapDrag)
        doubleTap.require(toFail: doubleTapDrag)
        longPress.require(toFail: doubleTapDrag)
        tap.require(toFail: doubleTap)
        multiDrag.require(toFail: doubleTapDrag)
    }
    
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer == pinchGestureRecognizer else {
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }
        /// Native scrolling resolves independent contacts in shouldReceive. An
        /// accepted pair may still take over a pan or drag; legacy keeps its gate.
        guard scrollController != nil || !canvas.isInteractionDragging else { return false }
        return canvas.delegate?.gestureCanvasAllowPinch(canvas) == true
    }
    
    @objc private func didTap(_ recognizer: GestureCanvasTapGestureRecognizer) {
        if recognizer.state == .ended {
            let location: CGPoint = recognizer.location(in: contentView) + canvas.zoomCoordinateOffset
            if canvas.interactionTap(at: location, count: 1, keyboardFlags: recognizer.keyboardFlags) { return }
            guard canvas.allowInteraction(at: location) else { return }
            canvas.backgroundTap(at: location)
        }
    }
    
    @objc private func didLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }
        let location: CGPoint = recognizer.location(in: contentView) + canvas.zoomCoordinateOffset
        if canvas.interactionLongPress(at: location) { return }
        guard canvas.allowInteraction(at: location) else { return }
        guard canvas.longPress(at: location) else { return }
        canvas.lastInteractionLocation = location
        let configuration = UIEditMenuConfiguration(identifier: nil, sourcePoint: recognizer.location(in: self))
        interaction?.presentEditMenu(with: configuration)
    }
    
    @objc private func didPan(_ recognizer: UIPanGestureRecognizer) {
        let location: CGPoint = recognizer.location(in: contentView) + canvas.zoomCoordinateOffset
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
        let location: CGPoint = recognizer.location(in: contentView) + canvas.zoomCoordinateOffset
        switch recognizer.state {
        case .possible:
            break
        case .began:
            /// Permission is resolved in `gestureRecognizerShouldBegin(_:)`.
            prepareForZoom()
            startZoom = Zoom(
                location: location,
                coordinate: scrollController == nil ? canvas.coordinate.unlimited : canvas.coordinate.limited
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
            if recognizer.state == .ended {
                canvas.willEndZoom(at: lastLocation)
            } else {
                canvas.cancelZoom()
            }
            let sequence = zoomSequence
            Task(name: "GestureCanvasInteractionUIView: Settle Pinch Zoom") { [weak self, canvas] in
                let completed = await canvas.gestureEnded(at: lastLocation)
                guard let self, zoomSequence == sequence else { return }
                canvas.didEndZoom(at: lastLocation)
                scrollController?.resumeAfterZoom(clamp: completed)
            }
        @unknown default:
            break
        }
    }
    
    @objc private func didDoubleTap(_ recognizer: GestureCanvasTapGestureRecognizer) {
        if recognizer.state == .ended {
            let location: CGPoint = recognizer.location(in: contentView) + canvas.zoomCoordinateOffset
            if canvas.interactionTap(at: location, count: 2, keyboardFlags: recognizer.keyboardFlags) { return }
            guard canvas.allowInteraction(at: location) else { return }
            canvas.backgroundDoubleTap(at: location)
        }
    }
    
    @objc private func didDoubleTapDrag(_ recognizer: DoubleTapDragGestureRecognizer) {
        let location: CGPoint = recognizer.location(in: contentView) + canvas.zoomCoordinateOffset
        switch recognizer.state {
        case .possible:
            break
        case .began:
            // Content handles object hits, while zoom remains a canvas gesture.
            // The background permission callback may deliberately reject those hits.
            guard canvas.interactionDelegate != nil || canvas.allowInteraction(at: location) else { return }
            prepareForZoom()
            startZoom = Zoom(
                location: location,
                coordinate: scrollController == nil ? canvas.coordinate.unlimited : canvas.coordinate.limited
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
            if recognizer.state == .ended {
                canvas.willEndZoom(at: startZoom.location)
            } else {
                canvas.cancelZoom()
            }
            let sequence = zoomSequence
            Task(name: "GestureCanvasInteractionUIView: Settle Double Tap Zoom") { [weak self, canvas] in
                let completed = await canvas.gestureEnded(at: startZoom.location)
                guard let self, zoomSequence == sequence else { return }
                canvas.didEndZoom(at: startZoom.location)
                scrollController?.resumeAfterZoom(clamp: completed)
            }
        @unknown default:
            break
        }
    }

    private func prepareForZoom() {
        zoomSequence &+= 1
        guard let scrollController else { return }
        scrollController.suspendForZoom()
        multiDragGestureRecognizer?.cancelForZoom()
        startPan = nil
    }
    
    // MARK: - Hover

    @objc private func didHover(_ recognizer: UIHoverGestureRecognizer) {
        switch recognizer.state {
        case .began, .changed:
            let location = recognizer.location(in: contentView) + canvas.zoomCoordinateOffset
            canvas.interactionHover(at: location)
        default:
            canvas.interactionHover(at: nil)
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
    
#endif

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
#if os(iOS)
        canvas.isIndirectTouching = false
#endif
        // UIKit also cancels raw view touches when SwiftUI recognizes a drag.
        // GestureCanvasGestureView owns drag cancellation through its GestureState;
        // cancelling here would abort an object drag as soon as it starts.
    }
    
    // MARK: - Presses

#if os(iOS)
    private var canvasKeyCommands: [UIKeyCommand] {
        guard let delegate = canvas.delegate as? any GestureCanvasKeyboardDelegate else { return [] }
        return delegate.gestureCanvasKeyCommands(canvas).map { shortcut in
            let command = UIKeyCommand(
                input: shortcut.key.input,
                modifierFlags: shortcut.modifierFlags,
                action: #selector(performCanvasKeyCommand(_:))
            )
            command.discoverabilityTitle = shortcut.title
            // Only offered while this canvas is first responder, never while typing.
            command.wantsPriorityOverSystemBehavior = true
            // Arrow navigation follows physical canvas directions in every layout.
            command.allowsAutomaticMirroring = false
            return command
        }
    }

    override var keyCommands: [UIKeyCommand]? {
        (super.keyCommands ?? []) + (isFirstResponder ? canvasKeyCommands : [])
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(performCanvasKeyCommand(_:)) {
            guard let command = sender as? UIKeyCommand else { return false }
            return canPerformCanvasKeyCommand(command)
        }
        return super.canPerformAction(action, withSender: sender)
    }

    private func canPerformCanvasKeyCommand(_ command: UIKeyCommand) -> Bool {
        guard isFirstResponder,
              let shortcut = canvasKeyCommand(for: command),
              let delegate = canvas.delegate as? any GestureCanvasKeyboardDelegate else { return false }
        return delegate.gestureCanvasCanPerformKeyCommand(canvas, key: shortcut.key, modifiers: shortcut.modifiers)
    }

    private func canvasKeyCommand(for command: UIKeyCommand) -> GestureCanvasKeyCommand? {
        guard let delegate = canvas.delegate as? any GestureCanvasKeyboardDelegate else { return nil }
        return delegate.gestureCanvasKeyCommands(canvas).first { shortcut in
            shortcut.key.input == command.input && shortcut.modifierFlags == command.modifierFlags
        }
    }

    @objc private func performCanvasKeyCommand(_ command: UIKeyCommand) {
        guard canPerformCanvasKeyCommand(command),
              let shortcut = canvasKeyCommand(for: command),
              let delegate = canvas.delegate as? any GestureCanvasKeyboardDelegate else { return }
        delegate.gestureCanvasPerformKeyCommand(canvas, key: shortcut.key, modifiers: shortcut.modifiers)
    }
#endif
    
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

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard gestureRecognizer == pinchGestureRecognizer,
              gestureRecognizer.state == .possible,
              scrollController != nil else { return true }
        return multiDragGestureRecognizer?.allowsPinch(toReceive: touch) ?? true
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        guard canvas.interactionDelegate != nil,
              gestureRecognizer == doubleTapDragGestureRecognizer,
              let otherView = otherGestureRecognizer.view,
              otherView.isDescendant(of: contentView) else { return false }
        // Reserve the second touch for zoom before hosted SwiftUI drags can
        // claim it. A first-touch drag releases this requirement when the
        // recognizer exceeds its normal tap movement threshold.
        return true
    }
    
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        if gestureRecognizer == hoverGestureRecognizer || otherGestureRecognizer == hoverGestureRecognizer {
            return true
        }
//        if gestureRecognizer == doublePanGestureRecognizer {
//            return true
//        }
        if gestureRecognizer == pinchGestureRecognizer {
            return otherGestureRecognizer != doubleTapDragGestureRecognizer
        }
        if gestureRecognizer == multiDragGestureRecognizer || otherGestureRecognizer == multiDragGestureRecognizer {
            // Every touch drags on its own, beside a pinch made of background touches.
            return gestureRecognizer != doubleTapDragGestureRecognizer
                && otherGestureRecognizer != doubleTapDragGestureRecognizer
        }
        return false
    }
}

#endif
