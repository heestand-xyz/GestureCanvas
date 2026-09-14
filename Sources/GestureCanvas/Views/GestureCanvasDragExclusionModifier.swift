import SwiftUI

/// Reserves the view's shape for hosted content gestures, leaving surrounding padding draggable.
struct GestureCanvasDragExclusionModifier<S: Shape>: ViewModifier {
    @Environment(GestureCanvas.self) private var canvas: GestureCanvas?
    @State private var id = UUID()
    @State private var frame: CGRect = .zero

    let shape: S
    let isEnabled: Bool

    private var path: Path? {
        isEnabled ? shape.path(in: frame) : nil
    }

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { geometry in
                geometry.frame(in: GestureCanvasCoordinate.space)
            } action: { frame in
                self.frame = frame
            }
            .onChange(of: path, initial: true) { _, path in
                canvas?.dragExclusionPaths[id] = path
            }
            .onDisappear {
                canvas?.dragExclusionPaths[id] = nil
            }
    }
}

// MARK: - View

extension View {
    public func gestureCanvasDragExclusion<S: Shape>(_ shape: S, isEnabled: Bool = true) -> some View {
        modifier(GestureCanvasDragExclusionModifier(shape: shape, isEnabled: isEnabled))
    }
}
