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

    func gestureCanvasChanged(_ canvas: GestureCanvas, coordinate: GestureCanvasDynamicCoordinate)
    
    func gestureCanvasBackgroundTap(_ canvas: GestureCanvas, at location: CGPoint)
    func gestureCanvasBackgroundDoubleTap(_ canvas: GestureCanvas, at location: CGPoint)
    
    func gestureCanvasDragSelectionStarted(_ canvas: GestureCanvas, at location: CGPoint)
    func gestureCanvasDragSelectionUpdated(_ canvas: GestureCanvas, at location: CGPoint)
    func gestureCanvasDragSelectionEnded(_ canvas: GestureCanvas, at location: CGPoint)

#if os(macOS)
    func gestureCanvasTrackpadLightMultiTap(_ canvas: GestureCanvas, tapCount: Int, at location: CGPoint)
    
    func gestureCanvasScrollStarted(_ canvas: GestureCanvas)
    func gestureCanvasScrollEnded(_ canvas: GestureCanvas)

    @MainActor
    func gestureCanvasContextMenu(_ canvas: GestureCanvas, at location: CGPoint) -> NSMenu?
#else
    func gestureCanvasContext(at location: CGPoint) -> CGPoint?
    func gestureCanvasEditMenuInteractionDelegate() -> UIEditMenuInteractionDelegate?

    func gestureCanvasAllowPinch(_ canvas: GestureCanvas) -> Bool
#endif
    
    func gestureCanvasDidStartPan(_ canvas: GestureCanvas, at location: CGPoint)
    func gestureCanvasDidUpdatePan(_ canvas: GestureCanvas, at location: CGPoint)
    func gestureCanvasDidEndPan(_ canvas: GestureCanvas, at location: CGPoint)
    func gestureCanvasDidCancelPan(_ canvas: GestureCanvas)
    
    func gestureCanvasDidStartZoom(_ canvas: GestureCanvas, at location: CGPoint)
    func gestureCanvasDidUpdateZoom(_ canvas: GestureCanvas, at location: CGPoint)
    func gestureCanvasDidEndZoom(_ canvas: GestureCanvas, at location: CGPoint)
    func gestureCanvasDidCancelZoom(_ canvas: GestureCanvas)
}

@MainActor
@Observable
public final class GestureCanvas: Sendable {
    
    @ObservationIgnored
    public weak var delegate: GestureCanvasDelegate?

    public private(set) var coordinate: GestureCanvasDynamicCoordinate {
        didSet {
            delegate?.gestureCanvasChanged(self, coordinate: coordinate)
        }
    }
    
    private var currentCoordinate: GestureCanvasCoordinate {
        if limitZoomIn {
            coordinate.limited
        } else {
            coordinate.unlimited
        }
    }
    
    @ObservationIgnored
    public var minimumScale: CGFloat? = 0.25
    @ObservationIgnored
    public var maximumScale: CGFloat? = 4.0
        
    public var limitZoomIn: Bool = false
    /// A fraction of what the limited scale will be beyond scale of 1.0.
    nonisolated public static let limitScale: CGFloat = 0.25
    
    public internal(set) var size: CGSize = .one
    
    public private(set) var isPanning: Bool = false
    
    func startPan(at location: CGPoint) {
        isPanning = true
        delegate?.gestureCanvasDidStartPan(self, at: location)
    }
    
    func updatePan(at location: CGPoint) {
        delegate?.gestureCanvasDidUpdatePan(self, at: location)
    }
    
    func endPan(at location: CGPoint) {
        isPanning = false
        delegate?.gestureCanvasDidEndPan(self, at: location)
    }
    
    func cancelPan() {
        isPanning = false
        delegate?.gestureCanvasDidCancelPan(self)
    }
    
    public private(set) var isZooming: Bool = false
    
    func startZoom(at location: CGPoint) {
        isZooming = true
        delegate?.gestureCanvasDidStartZoom(self, at: location)
    }
    
    func updateZoom(at location: CGPoint) {
        delegate?.gestureCanvasDidUpdateZoom(self, at: location)
    }
    
    func endZoom(at location: CGPoint) {
        isZooming = false
        delegate?.gestureCanvasDidEndZoom(self, at: location)
    }
    
    func cancelZoom() {
        isZooming = false
        delegate?.gestureCanvasDidCancelZoom(self)
    }
    
#if os(iOS)
    internal var isIndirectTouching: Bool = false
#endif
    internal private(set) var isSelecting: Bool = false
    
    public internal(set) var keyboardFlags: Set<GestureCanvasKeyboardFlag> = []
    
#if os(macOS)
    @ObservationIgnored
    public var trackpadEnabled: Bool = true
    
    @ObservationIgnored
    public internal(set) var mouseLocation: CGPoint?
    
    /// Magnifying with 2 fingers on the trackpad.
    internal var isMagnifying: Bool = false
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
    
    public var animationDuration: TimeInterval = 1.0 / 3.0
    private var moveAnimator: DisplayLinkAnimator?
    public var isAnimating: Bool {
        moveAnimator != nil
    }
    
    public init(coordinate: GestureCanvasCoordinate = .zero) {
        self.coordinate = .unlimited(coordinate)
    }
}

extension GestureCanvas {
    
    public func scale(to scale: CGFloat, animated: Bool = false) {
        move(to: GestureCanvasCoordinate(offset: currentCoordinate.offset, scale: scale))
    }
    
    public func scale(by scale: CGFloat, animated: Bool = false) {
        move(to: GestureCanvasCoordinate(offset: currentCoordinate.offset, scale: currentCoordinate.scale * scale))
    }
    
    public func offset(to offset: CGPoint, animated: Bool = false) {
        move(to: GestureCanvasCoordinate(offset: offset, scale: currentCoordinate.scale))
    }
    
    public func offset(by offset: CGPoint, animated: Bool = false) {
        move(to: GestureCanvasCoordinate(offset: currentCoordinate.offset + offset, scale: currentCoordinate.scale))
    }
    
    public func move(to coordinate: GestureCanvasCoordinate) {
        if isAnimating {
            cancelMoveAnimation()
        }
        if limitZoomIn {
            self.coordinate = .unlimited(hardLimitZoomIn(coordinate: coordinate))
        } else {
            self.coordinate = .unlimited(coordinate)
        }
    }
    
    internal func gestureStart() {
        if isAnimating {
            cancelMoveAnimation()
        }
    }
    
    internal func gestureUpdate(to coordinate: GestureCanvasCoordinate, at location: CGPoint) {
        if limitZoomIn {
            let limitedCoordinate: GestureCanvasCoordinate = softLimitZoomIn(
                coordinate: coordinate,
                at: location
            )
            self.coordinate = .limited(
                limitedCoordinate,
                unlimited: coordinate
            )
        } else {
            self.coordinate = .unlimited(coordinate)
        }
    }
    
    internal func gestureEnded(at location: CGPoint) {
        if limitZoomIn, coordinate.unlimited.scale > 1.0 {
            let hardLimitedCoordinate: GestureCanvasCoordinate = hardLimitZoomIn(
                coordinate: coordinate.unlimited,
                at: location
            )
            Task {
                await animate(
                    to: hardLimitedCoordinate
                )
            }
        }
    }
    
    public func animate(
        to coordinate: GestureCanvasCoordinate
    ) async {
        let targetCoordinate: GestureCanvasCoordinate = if limitZoomIn {
            hardLimitZoomIn(coordinate: coordinate)
        } else {
            coordinate
        }
        if isAnimating {
            cancelMoveAnimation()
        }
        let oldCoordinate = self.currentCoordinate
        let oldUnlimitedCoordinate = self.coordinate.unlimited
        moveAnimator = DisplayLinkAnimator(duration: animationDuration)
        await withCheckedContinuation { continuation in
            moveAnimator?.run { [weak self] progress in
                guard let self else { return }
                let fraction = progress.fractionWithEaseInOut(iterations: 2)
                let newCoordinate = GestureCanvasCoordinate(
                    offset: oldCoordinate.offset * (1.0 - fraction) + targetCoordinate.offset * fraction,
                    scale: oldCoordinate.scale * (1.0 - fraction) + targetCoordinate.scale * fraction
                )
                if limitZoomIn {
                    let newUnlimitedCoordinate = GestureCanvasCoordinate(
                        offset: oldUnlimitedCoordinate.offset * (1.0 - fraction) + targetCoordinate.offset * fraction,
                        scale: oldUnlimitedCoordinate.scale * (1.0 - fraction) + targetCoordinate.scale * fraction
                    )
                    self.coordinate = .limited(
                        newCoordinate,
                        unlimited: newUnlimitedCoordinate
                    )
                } else {
                    self.coordinate = .unlimited(newCoordinate)
                }
            } completion: { [weak self] completed in
                guard let self else { return }
                if completed, limitZoomIn {
                    self.coordinate = .unlimited(targetCoordinate)
                }
                moveAnimator = nil
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
        Self.coordinate(in: frame, padding: padding, size: size)
    }
    
    public static func coordinate(in frame: CGRect, padding: CGFloat = 0.0, size: CGSize) -> GestureCanvasCoordinate {
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
    
    /// Long press or secondary click on iPad trackpad
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

extension GestureCanvas {
    
    func dragSelectionStarted(at location: CGPoint) {
        isSelecting = true
        delegate?.gestureCanvasDragSelectionStarted(self, at: location)
    }
    
    func dragSelectionUpdated(at location: CGPoint) {
        delegate?.gestureCanvasDragSelectionUpdated(self, at: location)
    }
    
    func dragSelectionEnded(at location: CGPoint) {
        isSelecting = false
        delegate?.gestureCanvasDragSelectionEnded(self, at: location)
    }
}

#if os(macOS)

extension GestureCanvas {
    /// A light tap with multiple fingers on trackpad.
    func multiTap(count: Int, at location: CGPoint) {
        delegate?.gestureCanvasTrackpadLightMultiTap(self, tapCount: count, at: location)
    }
}

extension GestureCanvas {
    
    func dragSecondaryStarted(at location: CGPoint) {
        secondaryDragStartLocation = location
        secondaryDragStartCoordinate = coordinate.unlimited
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

// MARK: Limit Zoom In

extension GestureCanvas {
    
    /// Limit scale is zero a.k.a. no way to go beyond the zoom limit.
    public func hardLimitZoomIn(
        coordinate: GestureCanvasCoordinate,
        at location: CGPoint? = nil
    ) -> GestureCanvasCoordinate {
        Self.hardLimitZoomIn(
            coordinate: coordinate,
            at: location,
            size: size,
            minimumScale: minimumScale,
            maximumScale: maximumScale,
        )
    }
    
    /// Limit scale is zero a.k.a. no way to go beyond the zoom limit.
    public static func hardLimitZoomIn(
        coordinate: GestureCanvasCoordinate,
        at location: CGPoint? = nil,
        size: CGSize,
        minimumScale: CGFloat?,
        maximumScale: CGFloat?
    ) -> GestureCanvasCoordinate {
        softLimitZoomIn(
            coordinate: coordinate,
            at: location ?? (size.asPoint / 2),
            limitScale: 0.0,
            minimumScale: minimumScale,
            maximumScale: maximumScale
        )
    }
    
    /// Limit scale is default at 50%.
    public func softLimitZoomIn(
        coordinate: GestureCanvasCoordinate,
        at location: CGPoint,
        limitScale: CGFloat = limitScale
    ) -> GestureCanvasCoordinate {
        Self.softLimitZoomIn(
            coordinate: coordinate,
            at: location,
            limitScale: limitScale,
            minimumScale: minimumScale,
            maximumScale: maximumScale
        )
    }
    
    /// Limit scale is default at 50%.
    public static func softLimitZoomIn(
        coordinate: GestureCanvasCoordinate,
        at location: CGPoint,
        limitScale: CGFloat = limitScale,
        minimumScale: CGFloat?,
        maximumScale: CGFloat?
    ) -> GestureCanvasCoordinate {
        guard coordinate.scale > 1.0 else { return coordinate }
        var scale: CGFloat = 1.0 + (coordinate.scale - 1.0) * limitScale
        if let minimumScale = minimumScale {
            scale = max(scale, minimumScale)
        }
        if let maximumScale = maximumScale {
            scale = min(scale, maximumScale)
        }
        let magnification: CGFloat = scale / coordinate.scale
        let locationOffset: CGPoint = coordinate.offset - location
        let scaledLocationOffset: CGPoint = locationOffset * magnification
        let scaleOffset: CGPoint = scaledLocationOffset - locationOffset
        let offset: CGPoint = coordinate.offset + scaleOffset
        return GestureCanvasCoordinate(
            offset: offset,
            scale: scale
        )
    }
}
