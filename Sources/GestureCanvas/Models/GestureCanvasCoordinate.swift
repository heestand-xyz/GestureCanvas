import CoreGraphics
import CoreGraphicsExtensions

public struct GestureCanvasCoordinate: Equatable {
    
    public var offset: CGPoint
    public var scale: CGFloat
    
    public init(offset: CGPoint, scale: CGFloat) {
        self.offset = offset
        self.scale = scale
    }
}

extension GestureCanvasCoordinate {
    
    public static let zero = GestureCanvasCoordinate(offset: .zero, scale: 1.0)
}

extension GestureCanvasCoordinate {
    
    /// Converts from screen space to content space
    public func position(at location: CGPoint) -> CGPoint {
        (location - offset) / scale
    }
    
    /// Converts from content space to screen space
    public func location(at position: CGPoint) -> CGPoint {
        position * scale + offset
    }
}
