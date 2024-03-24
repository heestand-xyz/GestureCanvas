import CoreGraphics

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
