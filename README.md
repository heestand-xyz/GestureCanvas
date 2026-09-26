# Gesture Canvas

Gestures and rendered content share `GestureCanvasCoordinate.space` on the hosted
content root. Locations are measured from that root, plus `zoomCoordinateOffset`;
do not subtract safe-area insets again. Each canvas owns its own coordinate space,
including canvases in split views with different insets or section origins.

On iOS and visionOS, a `GestureCanvasDelegate` can opt into native panning by
returning the visible content rectangle from `gestureCanvasScrollBounds(_:)`.
Bounds are in canvas coordinates; the default `nil` keeps the original gestures.
Keep the returned bounds observable so changes to the content update the view.

The native mode uses an empty `UIScrollView` beside the rendered content. At each
zoom scale its content size is the scaled rectangle plus one viewport, giving
half a viewport of padding on all four sides. Each rectangle edge can therefore
reach the viewport center, including in portrait, landscape, and split views.
The app still owns camera recentering when its container resizes.

Content contacts keep using `GestureCanvasInteractionDelegate`; separate
background contacts can scroll alongside those drags. Pinch and double-tap-drag
zoom stay on the common parent, cancel panning and object drags, apply tension
outside the bounds, and animate back on release. Native scrolling resumes after
that animation. Touch and trackpad input remain available in the same session;
pointer click-drags continue to use the existing selection/content gestures.
macOS does not use this mode.

Pinch may take over during the first 250 ms of a drag. After that, a content drag
keeps its contact when another finger arrives; a held canvas pan also keeps its
contact when the new finger lands on content. The new finger can independently
drag a node/wire or scroll. The choice is made when that finger lands, so slowly
pinching with an early pair still works. Two background fingers can always pinch.
This arbitration applies to touch contacts, not trackpad pinch events.

Content edits rebase the scroll geometry without clamping the camera. In
particular, shrinking the folder by dragging an outer node inward must not move
the camera during the drop's final commit. The main delegate can await that commit
in `gestureCanvasWillSettleScrollBounds(_:)` (a no-op by default). After release,
the viewport animates back if it is outside the updated bounds. New gestures
cancel that return without changing the node's committed position.

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
