#if os(macOS)

import AppKit
import SwiftUI
import CoreGraphicsExtensions

public class GestureCanvasTrackpadNSView: NSView {
    
    private static let zoomScrollVelocityMultiplier: CGFloat = 0.0075
    private static let middleMouseScrollVelocityMultiplier: CGFloat = 10
    
    var canvas: GestureCanvas
    
    enum ScrollMethod {
        case pan
        case zoom
    }
    private var scrollMethod: ScrollMethod?
    private var scrollTimer: Timer?
    private let scrollTimeout: TimeInterval = 0.15
    private let scrollThreshold: CGFloat = 1.5
    
    @ObservationIgnored
    private var multiTapCount: Int = 0
    @ObservationIgnored
    private var multiTapBeganDate: Date?
    @ObservationIgnored
    private var multiTapTimer: Timer?
    private let multiTapMaximumDownTime: TimeInterval = 0.25
    private let multiTapMaximumWaitTime: TimeInterval = 0.25
    
    private let contentView: NSView?
    
    private var startCoordinate: GestureCanvasCoordinate?
    private var targetCoordinateScale: CGFloat?
    private var magnification: CGFloat?
    
    public init(canvas: GestureCanvas,
                contentView: NSView?) {
        
        self.canvas = canvas
        
        self.contentView = contentView
        
        super.init(frame: .zero)
        
        allowedTouchTypes = [.direct, .indirect]
        
        if let contentView {
            contentView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(contentView)
            NSLayoutConstraint.activate([
                contentView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
                contentView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor),
                contentView.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor),
                contentView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
            ])
        }
        
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] in
            self?.flagsChanged(with: $0)
            return $0
        }
        NSEvent.addLocalMonitorForEvents(matching: .magnify) { [weak self] in
            self?.magnify(with: $0)
            return $0
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResignKey),
            name: NSWindow.didResignKeyNotification,
            object: nil
        )
        
        becomeFirstResponder()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func windowDidResignKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window == self.window else { return }
        if scrollMethod != nil {
            cancelScroll()
        }
        canvas.keyboardFlags = []
    }
    
    public override func updateTrackingAreas() {
        let trackingArea = NSTrackingArea(rect: bounds, options: [
            .mouseMoved,
            .mouseEnteredAndExited,
            .activeInActiveApp
        ], owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }
    
    public var canBecomeFirstResponder: Bool { true }
    public func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        action.description.contains("context")
    }

    // MARK: - Mouse
    
    public override func mouseMoved(with event: NSEvent) {
        canvas.mouseLocation = getMouseLocation()
    }
    
    private func getMouseLocation() -> CGPoint? {
        guard let window: NSWindow else { return nil }
        let mouseLocation: CGPoint = window.mouseLocationOutsideOfEventStream
        guard let windowView: NSView = window.contentView else { return nil }
        var point: CGPoint = convert(.zero, to: windowView)
        if point.y == 0.0 { point = convert(CGPoint(x: 0.0, y: windowView.bounds.height), to: windowView) }
        let origin: CGPoint = CGPoint(x: point.x, y: windowView.bounds.size.height - point.y)
        let location: CGPoint = mouseLocation - origin
        let finalLocation: CGPoint = CGPoint(x: location.x, y: bounds.size.height - location.y)
        return finalLocation
    }
    
    // MARK: - Scroll
    
    public override func scrollWheel(with event: NSEvent) {
        guard canvas.trackpadEnabled else { return }
        guard !canvas.isMagnifying else { return }
        
        var delta: CGVector = CGVector(dx: event.scrollingDeltaX, dy: event.scrollingDeltaY)
        let withScrollWheel: Bool = !event.hasPreciseScrollingDeltas
        if withScrollWheel {
            delta *= Self.middleMouseScrollVelocityMultiplier
        }
        
        let scrollMethod: ScrollMethod = canvas.keyboardFlags.contains(.command) || withScrollWheel ? .zoom : .pan
        
        if scrollTimer == nil {
            guard max(abs(delta.dx), abs(delta.dy)) > scrollThreshold else { return }
            self.scrollMethod = scrollMethod
            didStartScroll(withScrollWheel: withScrollWheel)
        } else if let oldScrollMethod = self.scrollMethod, oldScrollMethod != scrollMethod {
            didEndScroll()
            self.scrollMethod = scrollMethod
            didStartScroll(withScrollWheel: withScrollWheel)
        }
        
        didScroll(by: delta)
        scrollTimer?.invalidate()
        scrollTimer = Timer(timeInterval: scrollTimeout, repeats: false, block: { [weak self] _ in
            self?.scrollTimer = nil
            self?.didEndScroll()
        })
        RunLoop.current.add(scrollTimer!, forMode: .common)
    }
    
    private func didStartScroll(withScrollWheel: Bool) {
        guard let location: CGPoint = getMouseLocation() else { return }
        startCoordinate = canvas.coordinate.unlimited
        targetCoordinateScale = canvas.coordinate.unlimited.scale
        canvas.isScrolling = true
        if scrollMethod == .zoom {
            canvas.startZoom(at: location)
        } else {
            canvas.startPan(at: location)
        }
        canvas.gestureStart()
    }
    
    private func didScroll(by velocity: CGVector) {
        guard let startCoordinate: GestureCanvasCoordinate else { return }
        guard let location: CGPoint = getMouseLocation() else { return }
        
        if isNaN(velocity.dx) || isNaN(velocity.dy) {
            print("Gesture Canvas - Scroll Delta is NaN")
            return
        }
        
        if scrollMethod == .zoom {
            guard let targetCoordinateScale: CGFloat else { return }
            let magnification: CGFloat = 1.0 + velocity.dy * Self.zoomScrollVelocityMultiplier
            var scale: CGFloat = targetCoordinateScale * magnification
            if let minimumScale = canvas.minimumScale {
                scale = max(scale, minimumScale)
            }
            if let maximumScale = canvas.maximumScale {
                scale = min(scale, maximumScale)
            }
            let offsetMagnification: CGFloat = scale / startCoordinate.scale
            let coordinate = GestureCanvasCoordinate(
                offset: (startCoordinate.offset - location) * offsetMagnification + location,
                scale: scale
            )
            canvas.gestureUpdate(to: coordinate, at: location)
            canvas.updateZoom(at: location)
            self.targetCoordinateScale = scale
        } else {
            var coordinate = canvas.coordinate.unlimited
            coordinate.offset += velocity.asPoint
            canvas.gestureUpdate(to: coordinate, at: location)
            canvas.updatePan(at: location)
        }
    }
    
    private func cancelScroll() {
        scrollTimer?.invalidate()
        scrollTimer = nil
        didEndScroll()
    }
    
    private func didEndScroll() {
        guard let location: CGPoint = getMouseLocation() else { return }
        canvas.gestureEnded(at: location)
        startCoordinate = nil
        canvas.isScrolling = false
        if scrollMethod == .zoom {
            canvas.endZoom(at: location)
        } else {
            canvas.endPan(at: location)
        }
        scrollMethod = nil
    }
    
    // MARK: - Magnify
    
    public override func magnify(with event: NSEvent) {
        guard window?.isKeyWindow == true else { return }
        guard canvas.trackpadEnabled else { return }
        guard var location: CGPoint = getMouseLocation() else { return }
        location += canvas.zoomCoordinateOffset
        guard bounds.contains(location) else { return }
        switch event.phase {
        case .began:
            if canvas.isScrolling {
                cancelScroll()
            }
            guard startCoordinate == nil else { return }
            startCoordinate = canvas.coordinate.unlimited
            magnification = 1.0
            canvas.isMagnifying = true
            canvas.startZoom(at: location)
            canvas.gestureStart()
        case .changed:
            guard let startCoordinate else { return }
            guard var magnification else { return }
            magnification += event.magnification
            var scale: CGFloat = startCoordinate.scale * magnification
            if let minimumScale = canvas.minimumScale {
                scale = max(scale, minimumScale)
            }
            if let maximumScale = canvas.maximumScale {
                scale = min(scale, maximumScale)
            }
            let finalMagnification: CGFloat = scale / startCoordinate.scale
            let coordinate = GestureCanvasCoordinate(
                offset: (startCoordinate.offset - location) * finalMagnification + location,
                scale: scale
            )
            canvas.gestureUpdate(to: coordinate, at: location)
            canvas.updateZoom(at: location)
            self.magnification = magnification
        case .ended, .cancelled:
            guard startCoordinate != nil else { return }
            canvas.gestureEnded(at: location)
            startCoordinate = nil
            magnification = nil
            canvas.isMagnifying = false
            canvas.endZoom(at: location)
        default:
            break
        }
    }
    
    // MARK: - Click
    
    public override func rightMouseDown(with event: NSEvent) {
        guard let location = getMouseLocation() else { return }
        canvas.dragSecondaryStarted(at: location)
        canvas.startPan(at: location)
    }
    
    public override func rightMouseDragged(with event: NSEvent) {
        guard let location = getMouseLocation() else { return }
        canvas.dragSecondaryUpdated(at: location)
        canvas.updatePan(at: location)
    }
    
    public override func rightMouseUp(with event: NSEvent) {
        guard let location = getMouseLocation() else { return }
        let action = canvas.dragSecondaryEnded(at: location)
        canvas.endPan(at: location)
        switch action {
        case .context(let menu):
            NSMenu.popUpContextMenu(menu, with: event, for: self)
        case .ignore:
            break
        }
    }
    
    // MARK: - Touch
    
    public override func touchesBegan(with event: NSEvent) {
        super.touchesBegan(with: event)
        let touches: Set<NSTouch> = event.touches(matching: .began, in: self)
        guard touches.count >= 2 else { return }
        guard touches.allSatisfy({ $0.type == .indirect }) else { return }
        multiTapTimer?.invalidate()
        multiTapTimer = nil
        multiTapBeganDate = .now
    }
    
    public override func touchesEnded(with event: NSEvent) {
        super.touchesEnded(with: event)
        guard let date: Date = multiTapBeganDate else { return }
        defer { multiTapBeganDate = nil }
        guard date.distance(to: .now) < multiTapMaximumDownTime else {
            cancelMultiTap()
            return
        }
        multiTapCount += 1
        multiTapTimer?.invalidate()
        multiTapTimer = .scheduledTimer(withTimeInterval: multiTapMaximumWaitTime, repeats: false) { [weak self] _ in
            guard let self else { return }
            if let location = getMouseLocation() {
                didMultiTap(count: multiTapCount, at: location)
            }
            multiTapCount = 0
            multiTapTimer = nil
        }
    }
    
    public override func touchesCancelled(with event: NSEvent) {
        super.touchesCancelled(with: event)
        cancelMultiTap()
    }
    
    // MARK: - Multi Tap
    
    private func didMultiTap(count: Int, at location: CGPoint) {
        canvas.multiTap(count: count, at: location)
    }
    
    private func cancelMultiTap() {
        multiTapTimer?.invalidate()
        multiTapTimer = nil
        multiTapCount = 0
        multiTapBeganDate = nil
    }
    
    // MARK: - Flags
    
    public override func flagsChanged(with event: NSEvent) {
        var keyboardFlags: Set<GestureCanvasKeyboardFlag> = []
        switch event.modifierFlags.intersection(.deviceIndependentFlagsMask) {
        case .command:
            keyboardFlags.insert(.command)
        case .control:
            keyboardFlags.insert(.control)
        case .shift:
            keyboardFlags.insert(.shift)
        case .option:
            keyboardFlags.insert(.option)
        default:
            break
        }
        canvas.keyboardFlags = keyboardFlags
    }
    
    // MARK: - NaN
    
    private func isNaN(_ value: CGFloat) -> Bool {
        value == .nan || "\(value)".lowercased() == "nan"
    }
}

#endif
