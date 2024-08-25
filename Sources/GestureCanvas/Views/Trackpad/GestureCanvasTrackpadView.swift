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
        context.coordinator.refreshIfNeeded(refreshID: canvas.refreshID)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(refreshID: canvas.refreshID, content: content)
    }
    
    class Coordinator {

        private var lastRefreshID: UUID

        private let content: () -> Content

        var hostingController: NSHostingController<Content>?

        init(refreshID: UUID, content: @escaping () -> Content) {
            lastRefreshID = refreshID
            self.content = content
        }
        
        func refreshIfNeeded(refreshID: UUID) {
            if lastRefreshID == refreshID { return }
            refresh()
            lastRefreshID = refreshID
        }
        
        private func refresh() {
            hostingController?.rootView = content()
        }
    }
}

#endif
