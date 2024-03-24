import CoreGraphics

public enum GestureCanvasGridStyle {
    case one
    case fractions([CGFloat])
}

extension GestureCanvasGridStyle {
    
    static let treeTen: Self = .fractions([0.1, 1.0, 10.0])
}
