import Observation
import CoreGraphics
import CoreGraphicsExtensions

public protocol GestureCanvasDelegate: AnyObject {
    
    func gestureCanvasBackgroundTap(at location: CGPoint)
    func gestureCanvasBackgroundDoubleTap(at location: CGPoint)
    
    func gestureCanvasDragSelectionStarted(at location: CGPoint)
    func gestureCanvasDragSelectionUpdated(at location: CGPoint)
    func gestureCanvasDragSelectionEnded(at location: CGPoint)
}

@Observable
public final class GestureCanvas {
    
    @ObservationIgnored
    public weak var delegate: GestureCanvasDelegate?
    
    public var coordinate: GestureCanvasCoordinate = .zero
    
    @ObservationIgnored
    public var minimumScale: CGFloat = 0.25
    @ObservationIgnored
    public var maximumScale: CGFloat = 4.0
    
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
 
    func backgroundTap(at location: CGPoint) {
        delegate?.gestureCanvasBackgroundTap(at: location)
    }
 
    func backgroundDoubleTap(at location: CGPoint) {
        delegate?.gestureCanvasBackgroundDoubleTap(at: location)
    }
}

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
