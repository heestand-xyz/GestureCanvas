import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif
import Observation
import Combine
import CoreGraphics
import CoreGraphicsExtensions
import DisplayLink

@MainActor
public protocol GestureCanvasDelegate: AnyObject {

    func gestureCanvasChanged(_ canvas: GestureCanvas, coordinate: GestureCanvasCoordinate)
    
    func gestureCanvasBackgroundTap(_ canvas: GestureCanvas, at location: CGPoint)
    func gestureCanvasBackgroundDoubleTap(_ canvas: GestureCanvas, at location: CGPoint)
    
#if os(macOS)
    func gestureCanvasDragSelectionStarted(_ canvas: GestureCanvas, at location: CGPoint)
    func gestureCanvasDragSelectionUpdated(_ canvas: GestureCanvas, at location: CGPoint)
    func gestureCanvasDragSelectionEnded(_ canvas: GestureCanvas, at location: CGPoint)

    func gestureCanvasScrollStarted(_ canvas: GestureCanvas)
    func gestureCanvasScrollEnded(_ canvas: GestureCanvas)

    @MainActor
    func gestureCanvasContextMenu(_ canvas: GestureCanvas, at location: CGPoint) -> NSMenu?
#else
    func gestureCanvasContext(at location: CGPoint) -> CGPoint?
    func gestureCanvasEditMenuInteractionDelegate() -> UIEditMenuInteractionDelegate?

    func gestureCanvasAllowPinch(_ canvas: GestureCanvas) -> Bool
#endif
    
    func gestureCanvasDidStartPan(_ canvas: GestureCanvas)
    func gestureCanvasDidEndPan(_ canvas: GestureCanvas)
    func gestureCanvasDidStartZoom(_ canvas: GestureCanvas)
    func gestureCanvasDidEndZoom(_ canvas: GestureCanvas)
}

@MainActor
@Observable
public final class GestureCanvas {
    
    @ObservationIgnored
    public weak var delegate: GestureCanvasDelegate?
    
    public private(set) var coordinate: GestureCanvasCoordinate = .zero {
        didSet {
            delegate?.gestureCanvasChanged(self, coordinate: coordinate)
        }
    }
    
    @ObservationIgnored
    public var minimumScale: CGFloat? = 0.25
    @ObservationIgnored
    public var maximumScale: CGFloat? = 4.0
    
    public internal(set) var size: CGSize = .one
    
    @available(*, deprecated, renamed: "isZooming")
    public var isPinching: Bool {
        isZooming
    }
    
    public internal(set) var isPanning: Bool = false {
        didSet {
            if isPanning {
                delegate?.gestureCanvasDidStartPan(self)
            } else {
                delegate?.gestureCanvasDidEndPan(self)
            }
        }
    }
    
    public internal(set) var isZooming: Bool = false {
        didSet {
            if isZooming {
                delegate?.gestureCanvasDidStartZoom(self)
            } else {
                delegate?.gestureCanvasDidEndZoom(self)
            }
        }
    }
    
#if os(macOS)
    @ObservationIgnored
    public var trackpadEnabled: Bool = true
    @ObservationIgnored
    public internal(set) var mouseLocation: CGPoint?
    public internal(set) var keyboardFlags: Set<GestureCanvasKeyboardFlag> = []
    public internal(set) var isScrolling: Bool = false {
        didSet {
            if isScrolling {
                delegate?.gestureCanvasScrollStarted(self)
            } else {
                delegate?.gestureCanvasScrollEnded(self)
            }
        }
    }
#else
    @ObservationIgnored
    public internal(set) var lastInteractionLocation: CGPoint?
#endif
    
    @ObservationIgnored
    private var startCoordinate: GestureCanvasCoordinate?
    
#if os(macOS)
    private var secondaryDragStartLocation: CGPoint?
    private var secondaryDragStartCoordinate: GestureCanvasCoordinate?
#endif

    /// Use to offset coordinate if origin is not in the container view origin.
    public var zoomCoordinateOffset: CGPoint = .zero
    
    public var animationDuration: TimeInterval = 0.5
    private var moveAnimator: DisplayLinkAnimator?
    public var isAnimating: Bool {
        moveAnimator != nil
    }
    
    public init() {}
}

extension GestureCanvas {
    
    public func scale(to scale: CGFloat, animated: Bool = false) {
        move(to: GestureCanvasCoordinate(offset: coordinate.offset, scale: scale))
    }
    
    public func scale(by scale: CGFloat, animated: Bool = false) {
        move(to: GestureCanvasCoordinate(offset: coordinate.offset, scale: coordinate.scale * scale))
    }
    
    public func offset(to offset: CGPoint, animated: Bool = false) {
        move(to: GestureCanvasCoordinate(offset: offset, scale: coordinate.scale))
    }
    
    public func offset(by offset: CGPoint, animated: Bool = false) {
        move(to: GestureCanvasCoordinate(offset: coordinate.offset + offset, scale: coordinate.scale))
    }
    
    public func move(to coordinate: GestureCanvasCoordinate) {
        if isAnimating {
            cancelMoveAnimation()
        }
        self.coordinate = coordinate
    }
    
    public func animate(to coordinate: GestureCanvasCoordinate) async {
        if isAnimating {
            cancelMoveAnimation()
        }
        let oldCoordinate = self.coordinate
        moveAnimator = DisplayLinkAnimator(duration: animationDuration)
        await withCheckedContinuation { continuation in
            moveAnimator?.run { [weak self] progress in
                let fraction = progress.fractionWithEaseInOut(iterations: 2)
                let newCoordinate = GestureCanvasCoordinate(
                    offset: oldCoordinate.offset * (1.0 - fraction) + coordinate.offset * fraction,
                    scale: oldCoordinate.scale * (1.0 - fraction) + coordinate.scale * fraction
                )
                self?.coordinate = newCoordinate
            } completion: { [weak self] _ in
                self?.moveAnimator = nil
                continuation.resume()
            }
        }
    }
    
    private func cancelMoveAnimation() {
        moveAnimator?.cancel()
        moveAnimator = nil
    }
}

extension GestureCanvas {
    
    public func coordinate(in frame: CGRect, padding: CGFloat = 0.0) -> GestureCanvasCoordinate {
        let targetFrame: CGRect = CGRect(
            origin: frame.origin - padding,
            size: frame.size + (padding * 2)
        )
        let fitScale: CGFloat = min(
            size.width / targetFrame.width,
            size.height / targetFrame.height
        )
        let fitOffset: CGPoint = size / 2 - targetFrame.center * fitScale
        return GestureCanvasCoordinate(
            offset: fitOffset,
            scale: fitScale
        )
    }
}

#if !os(macOS)
extension GestureCanvas {
    
    public func didLongPressInteraction() {
        lastInteractionLocation = nil
    }
    
    func longPress(at location: CGPoint) -> CGPoint? {
        delegate?.gestureCanvasContext(at: location)
    }
}
#endif

extension GestureCanvas {
    
    func backgroundTap(at location: CGPoint) {
        delegate?.gestureCanvasBackgroundTap(self, at: location)
    }
    
    func backgroundDoubleTap(at location: CGPoint) {
        delegate?.gestureCanvasBackgroundDoubleTap(self, at: location)
    }
}

#if os(macOS)

extension GestureCanvas {
 
    func dragSelectionStarted(at location: CGPoint) {
        delegate?.gestureCanvasDragSelectionStarted(self, at: location)
    }
 
    func dragSelectionUpdated(at location: CGPoint) {
        delegate?.gestureCanvasDragSelectionUpdated(self, at: location)
    }
 
    func dragSelectionEnded(at location: CGPoint) {
        delegate?.gestureCanvasDragSelectionEnded(self, at: location)
    }
}

extension GestureCanvas {
 
    func dragSecondaryStarted(at location: CGPoint) {
        secondaryDragStartLocation = location
        secondaryDragStartCoordinate = coordinate
    }
 
    func dragSecondaryUpdated(at location: CGPoint) {
        guard let startLocation: CGPoint = secondaryDragStartLocation else { return }
        guard var coordinate: GestureCanvasCoordinate = secondaryDragStartCoordinate else { return }
        let offset: CGPoint = location - startLocation
        coordinate.offset += offset
        move(to: coordinate)
    }
    
    enum SecondaryEndAction {
        case ignore
        case context(NSMenu)
    }
 
    @MainActor
    func dragSecondaryEnded(at location: CGPoint) -> SecondaryEndAction {
        defer {
            secondaryDragStartLocation = nil
            secondaryDragStartCoordinate = nil
        }
        guard let startLocation: CGPoint = secondaryDragStartLocation else { return .ignore }
        let offset: CGPoint = location - startLocation
        let distance = hypot(offset.x, offset.y)
        guard distance < 10 else { return .ignore }
        guard let contextMenu: NSMenu = delegate?.gestureCanvasContextMenu(self, at: location) else { return .ignore }
        return .context(contextMenu)
    }
}

#endif
