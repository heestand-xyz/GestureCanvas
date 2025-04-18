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
    func gestureCanvasDidStartPinch(_ canvas: GestureCanvas)
    func gestureCanvasDidEndPinch(_ canvas: GestureCanvas)
#endif
}

@MainActor
@Observable
public final class GestureCanvas {
    
    @ObservationIgnored
    public weak var delegate: GestureCanvasDelegate?
    
    public var coordinate: GestureCanvasCoordinate = .zero {
        didSet {
            delegate?.gestureCanvasChanged(self, coordinate: coordinate)
        }
    }
    
    @ObservationIgnored
    public var minimumScale: CGFloat = 0.25
    @ObservationIgnored
    public var maximumScale: CGFloat = 4.0
    
    public internal(set) var size: CGSize = .one
    
#if !os(macOS)
    public internal(set) var isPinching: Bool = false {
        didSet {
            if isPinching {
                delegate?.gestureCanvasDidStartPinch(self)
            } else {
                delegate?.gestureCanvasDidEndPinch(self)
            }
        }
    }
#endif
    
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
    
    public init() {}
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
        self.coordinate = coordinate
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
