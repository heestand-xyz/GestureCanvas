#if os(macOS)

import AppKit
import SwiftUI
import CoreGraphicsExtensions

public class GestureCanvasTrackpadNSView: NSView {
    
//    private static let velocityStartDampenThreshold: CGFloat = 2.5
//    private static let velocityRadiusThreshold: CGFloat = 0.02
//    private static let snapAngleThreshold: Angle = Angle(degrees: 5)
//    private static let isOnGridRadiusThreshold: CGFloat = 0.2
//    private static let initialRotationThreshold: Angle = Angle(degrees: 10)
    private static let zoomScrollVelocityMultiplier: CGFloat = 0.0075
    private static let middleMouseScrollVelocityMultiplier: CGFloat = 10
//    private static let middleMouseDragVelocityMultiplier: CGFloat = 0.01

    var canvas: GestureCanvas
    
    var scrollTimer: Timer?
    let scrollTimeout: Double = 0.15
    let scrollThreshold: CGFloat = 1.5
    
    private let contentView: NSView?
    
    private var startCoordinate: GestureCanvasCoordinate?
    
    public init(canvas: GestureCanvas,
                contentView: NSView?) {
        
        self.canvas = canvas
        
        self.contentView = contentView

        super.init(frame: .zero)
        
        if let contentView {
            contentView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(contentView)
            NSLayoutConstraint.activate([
                contentView.topAnchor.constraint(equalTo: topAnchor),
                contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
                contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
                contentView.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
        }
        
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] in
            self?.flagsChanged(with: $0)
            return $0
        }
        NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [weak self] in
            self?.mouseUp(with: $0)
            return $0
        }
        NSEvent.addLocalMonitorForEvents(matching: .magnify) { [weak self] in
            self?.magnify(with: $0)
            return $0
        }
        NSEvent.addLocalMonitorForEvents(matching: .rotate) { [weak self] in
            self?.rotate(with: $0)
            return $0
        }
        
        becomeFirstResponder()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    public override func updateTrackingAreas() {
        let trackingArea = NSTrackingArea(rect: bounds, options: [
            .mouseMoved,
//            .enabledDuringMouseDrag,
            .mouseEnteredAndExited,
            .activeInKeyWindow,
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
    
    func getMouseLocation() -> CGPoint? {
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
        
        var delta: CGVector = CGVector(dx: event.scrollingDeltaX, dy: event.scrollingDeltaY)
        let withScrollWheel: Bool = !event.hasPreciseScrollingDeltas
        if withScrollWheel {
            delta *= Self.middleMouseScrollVelocityMultiplier
        }
        
        if scrollTimer == nil {
            guard max(abs(delta.dx), abs(delta.dy)) > scrollThreshold else { return }
            didStartScroll()
        }
        
        didScroll(by: delta, withScrollWheel)
        
        scrollTimer?.invalidate()
        scrollTimer = Timer(timeInterval: scrollTimeout, repeats: false, block: { [weak self] _ in
            self?.scrollTimer = nil
            self?.didEndScroll()
        })
        RunLoop.current.add(scrollTimer!, forMode: .common)
    }
    
    func didStartScroll() {
        startCoordinate = canvas.coordinate
    }
    
    func didScroll(by velocity: CGVector, _ withScrollWheel: Bool) {
        guard let startCoordinate: GestureCanvasCoordinate else { return }
        guard let location: CGPoint = getMouseLocation() else { return }
        
        if isNaN(velocity.dx) || isNaN(velocity.dy) {
            print("Gesture Canvass - Scroll Delta is NaN")
            return
        }
        
        if canvas.keyboardFlags.contains(.command) || withScrollWheel {
            let magnification: CGFloat = 1.0 + velocity.dy * Self.zoomScrollVelocityMultiplier
            
            var scale: CGFloat = canvas.coordinate.scale * magnification
            scale = min(max(scale, canvas.minimumScale), canvas.maximumScale)
            canvas.coordinate.scale = scale
            let offsetMagnification: CGFloat = scale / startCoordinate.scale
            canvas.coordinate.offset = (startCoordinate.offset - location) * offsetMagnification + location
            
        } else {
            canvas.coordinate.offset += velocity
        }
    }
    
    func didEndScroll() {
        startCoordinate = nil
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