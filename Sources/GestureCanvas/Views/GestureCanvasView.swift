import SwiftUI

public struct GestureCanvasView<FG: View, BG: View>: View {
    
    @Bindable var canvas: GestureCanvas
    
    let background: () -> BG
    let foreground: () -> FG
    
    public init(canvas: GestureCanvas,
                @ViewBuilder background: @escaping () -> BG,
                @ViewBuilder foreground: @escaping () -> FG) {
        self.canvas = canvas
        self.background = background
        self.foreground = foreground
    }
    
    public var body: some View {
        ZStack(alignment: .topLeading) {
            background()
                .gesture(
                    SpatialTapGesture(count: 2)
                        .onEnded { value in
                            canvas.backgroundDoubleTap(at: value.location)
                        }
                )
                .gesture(
                    SpatialTapGesture(count: 1)
                        .onEnded { value in
                            canvas.backgroundTap(at: value.location)
                        }
                )
#if os(macOS)
            GestureCanvasTrackpadView(canvas: canvas) {
                ZStack(alignment: .topLeading) {
                    GestureCanvasGestureView(canvas: canvas)
                    foreground()
                }
            }
#else
            GestureCanvasGestureView(canvas: canvas)
            foreground()
#endif
        }
    }
}
