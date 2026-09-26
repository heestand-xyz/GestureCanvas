#if os(macOS)

import AppKit
import SwiftUI
import CoreGraphicsExtensions

struct GestureCanvasTrackpadView<Content: View>: NSViewRepresentable {
    
    let canvas: GestureCanvas
    let contentBounds: CGRect?
    let content: () -> Content
    
    func makeNSView(context: Context) -> GestureCanvasTrackpadNSView {
        let hostingController = NSHostingController(rootView: content())
        context.coordinator.hostingController = hostingController
        let contentView: NSView = hostingController.view
        let view = GestureCanvasTrackpadNSView(canvas: canvas, contentView: contentView)
        canvas.updateBounds(contentBounds, viewportSize: contentView.bounds.size)
        return view
    }
    
    func updateNSView(_ trackpadView: GestureCanvasTrackpadNSView, context: Context) {
        context.coordinator.content = content
        context.coordinator.refresh()
        canvas.updateBounds(contentBounds, viewportSize: trackpadView.viewportSize)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(content: content)
    }
    
    class Coordinator {

        var content: () -> Content

        var hostingController: NSHostingController<Content>?

        init(content: @escaping () -> Content) {
            self.content = content
        }

        func refresh() {
            hostingController?.rootView = content()
        }
    }
}

#endif
