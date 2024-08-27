# Gesture Canvas

```swift
import SwiftUI
import GestureCanvas

struct ContentView: View {
    
    @State private var canvas = GestureCanvas()
    
    var body: some View {
        GestureCanvasView(canvas: canvas) {
            ZStack {
                YourBackgroundView()
                GestureCanvasGrid(size: 100, style: .one, coordinate: canvas.coordinate)
            }
        } foreground: {
            ZStack {
                GestureCanvasGestureView(canvas: canvas)
                YourForegroundView()
                    .offset(x: canvas.coordinate.offset.x,
                            y: canvas.coordinate.offset.y)
            }
        }
    }
}
```
