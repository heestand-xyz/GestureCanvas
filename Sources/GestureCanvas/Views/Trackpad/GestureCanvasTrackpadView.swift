#if os(macOS)

import AppKit
import SwiftUI
import CoreGraphicsExtensions

struct GestureCanvasTrackpadView<Content: View>: NSViewRepresentable {
    
    let canvas: GestureCanvas
    let content: () -> Content
    
    func makeNSView(context: Context) -> GestureCanvasTrackpadNSView {
        let contentView: NSView = NSHostingController(rootView: content()).view
        return GestureCanvasTrackpadNSView(canvas: canvas, contentView: contentView)
    }
    
    func updateNSView(_ trackpadView: GestureCanvasTrackpadNSView, context: Context) {}
}

#endif
