# Gesture Canvas

```swift
import SwiftUI
import GestureCanvas

struct ContentView: View {
    
    @State private var canvas = GestureCanvas()
    
    var body: some View {
        ZStack {
            GestureCanvasGrid(size: 100, style: .one, coordinate: canvas.coordinate)
            GestureCanvasView(canvas: canvas) { gestureContent in
                gestureContent
#if os(macOS)
                    .contextMenu {
                        /// Custom Canvas macOS Context Menu
                    }
#endif
            } content: {
                CustomCanvasView()
                    .offset(x: canvas.coordinate.offset.x,
                            y: canvas.coordinate.offset.y)
            }
        }
        .onAppear {
#if os(iOS)
            /// Custom Canvas iOS Context Menu
            canvas.addLongPress(delegate: ...)
#endif
        }
    }
}
```
