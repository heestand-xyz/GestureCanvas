import SwiftUI

public struct GestureCanvasView<Content: View, GestureContent: View>: View {
    
    @Bindable var canvas: GestureCanvas
    
    let gestureContent: (GestureCanvasGestureView) -> GestureContent
    let content: () -> Content
    
    public init(canvas: GestureCanvas,
                @ViewBuilder gestureContent: @escaping (GestureCanvasGestureView) -> GestureContent = { $0 },
                @ViewBuilder content: @escaping () -> Content) {
        self.canvas = canvas
        self.gestureContent = gestureContent
        self.content = content
    }
    
    public var body: some View {
        ZStack(alignment: .topLeading) {
#if os(macOS)
            GestureCanvasTrackpadView(canvas: canvas) {
                ZStack(alignment: .topLeading) {
                    gestureContent(GestureCanvasGestureView(canvas: canvas))
                    content()
                }
            }
#else
            ZStack(alignment: .topLeading) {
                GestureCanvasInteractionView(canvas: canvas) {
                    gestureContent(GestureCanvasGestureView(canvas: canvas))
                }
                content()
            }
#endif
        }
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
