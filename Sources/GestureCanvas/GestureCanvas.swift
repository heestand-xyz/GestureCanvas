import Observation
import Combine
import CoreGraphics
import CoreGraphicsExtensions

public protocol GestureCanvasDelegate: AnyObject {
    
    func gestureCanvasChanged(coordinate: GestureCanvasCoordinate)
    
    func gestureCanvasBackgroundTap(at location: CGPoint)
    func gestureCanvasBackgroundDoubleTap(at location: CGPoint)
    
#if os(macOS)
    func gestureCanvasDragSelectionStarted(at location: CGPoint)
    func gestureCanvasDragSelectionUpdated(at location: CGPoint)
    func gestureCanvasDragSelectionEnded(at location: CGPoint)
#endif
}

@Observable
public final class GestureCanvas {
    
    @ObservationIgnored
    public weak var delegate: GestureCanvasDelegate?
    
    public var coordinate: GestureCanvasCoordinate = .zero {
        didSet {
            delegate?.gestureCanvasChanged(coordinate: coordinate)
        }
    }
    
    @ObservationIgnored
    public var minimumScale: CGFloat = 0.25
    @ObservationIgnored
    public var maximumScale: CGFloat = 4.0
    
    public internal(set) var size: CGSize = .one
    
#if os(macOS)
    @ObservationIgnored
    public var trackpadEnabled: Bool = true
    @ObservationIgnored
    public internal(set) var mouseLocation: CGPoint?
    public internal(set) var keyboardFlags: Set<GestureCanvasKeyboardFlag> = []
#endif
    
    @ObservationIgnored
    private var startCoordinate: GestureCanvasCoordinate?
    
    public init() {}
}

extension GestureCanvas {
    
    public func coordinate(in frame: CGRect, padding: CGFloat = 0.0) -> GestureCanvasCoordinate {
        let targetScale: CGFloat = min(
            size.width / frame.width,
            size.height / frame.height
        )
        let targetFrame: CGRect = CGRect(
            origin: frame.origin - padding * targetScale,
            size: frame.size + (padding * 2) * targetScale
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

extension GestureCanvas {
    
    func backgroundTap(at location: CGPoint) {
        delegate?.gestureCanvasBackgroundTap(at: location)
    }
    
    func backgroundDoubleTap(at location: CGPoint) {
        delegate?.gestureCanvasBackgroundDoubleTap(at: location)
    }
}

#if os(macOS)

extension GestureCanvas {
 
    func dragSelectionStarted(at location: CGPoint) {
        delegate?.gestureCanvasDragSelectionStarted(at: location)
    }
 
    func dragSelectionUpdated(at location: CGPoint) {
        delegate?.gestureCanvasDragSelectionUpdated(at: location)
    }
 
    func dragSelectionEnded(at location: CGPoint) {
        delegate?.gestureCanvasDragSelectionEnded(at: location)
    }
}

#endif
