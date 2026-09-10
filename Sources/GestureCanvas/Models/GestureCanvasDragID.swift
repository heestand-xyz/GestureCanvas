import Foundation

/// Identifies one drag. A multi touch canvas runs several drags at the same time.
public struct GestureCanvasDragID: Hashable, Sendable {
    
    private let rawValue: UUID
    
    public init() {
        rawValue = UUID()
    }
}
