import SwiftUI

public struct GestureCanvasView<Content: View, GestureContent: View>: View {
    
    @Bindable var canvas: GestureCanvas
    
    let preservesContentAnimations: Bool
    let gestureContent: (GestureCanvasGestureView) -> GestureContent
    let content: () -> Content
    
    /// Enable `preservesContentAnimations` to forward SwiftUI animation transactions
    /// through a stable hosted root. The default uses direct root-view updates.
    public init(canvas: GestureCanvas,
                preservesContentAnimations: Bool = false,
                @ViewBuilder gestureContent: @escaping (GestureCanvasGestureView) -> GestureContent = { $0 },
                @ViewBuilder content: @escaping () -> Content) {
        self.canvas = canvas
        self.preservesContentAnimations = preservesContentAnimations
        self.gestureContent = gestureContent
        self.content = content
    }
    
    public var body: some View {
        ZStack(alignment: .topLeading) {
#if os(macOS)
            GestureCanvasTrackpadView(
                canvas: canvas,
                contentBounds: canvas.delegate?.gestureCanvasBounds(canvas),
                preservesContentAnimations: preservesContentAnimations
            ) {
                ZStack(alignment: .topLeading) {
                    gestureContent(GestureCanvasGestureView(canvas: canvas))
                    content()
                }
                .coordinateSpace(GestureCanvasCoordinate.space)
            }
            .id(preservesContentAnimations)
#else
            GestureCanvasInteractionView(
                canvas: canvas,
                contentBounds: canvas.delegate?.gestureCanvasBounds(canvas),
                usesNativeScrolling: canvas.delegate?.gestureCanvasUsesNativeScrolling(canvas) == true,
                preservesContentAnimations: preservesContentAnimations
            ) {
                ZStack(alignment: .topLeading) {
                    gestureContent(GestureCanvasGestureView(canvas: canvas))
                    content()
                }
                .coordinateSpace(GestureCanvasCoordinate.space)
            }
            .id(preservesContentAnimations)
#endif
        }
        .environment(canvas)
        // iOS 18 & macOS 15
//        .onGeometryChange(for: CGSize.self) { geometry in
//            geometry.size
//        } action: { _, newSize in
//            canvas.size = newSize
//        }
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        canvas.size = geometry.size
                    }
                    .onChange(of: geometry.size) { _, newSize in
                        canvas.size = newSize
                    }
            }
        }
    }
}
