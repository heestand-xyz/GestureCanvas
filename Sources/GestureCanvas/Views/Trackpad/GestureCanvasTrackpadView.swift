#if os(macOS)

import AppKit
import SwiftUI
import CoreGraphicsExtensions

struct GestureCanvasTrackpadView<Content: View>: NSViewRepresentable {
    
    let canvas: GestureCanvas
    let content: () -> Content
    
    func makeNSView(context: Context) -> GestureCanvasTrackpadNSView {
        let hostingController = NSHostingController(rootView: content())
        context.coordinator.hostingController = hostingController
        let contentView: NSView = hostingController.view
        return GestureCanvasTrackpadNSView(canvas: canvas, contentView: contentView)
    }
    
    func updateNSView(_ trackpadView: GestureCanvasTrackpadNSView, context: Context) {
        context.coordinator.refresh()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(content: content)
    }
    
    class Coordinator {

        private let content: () -> Content

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
