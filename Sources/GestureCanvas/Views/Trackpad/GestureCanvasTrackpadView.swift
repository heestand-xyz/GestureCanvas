#if os(macOS)

import AppKit
import SwiftUI
import CoreGraphicsExtensions

struct GestureCanvasTrackpadView<Content: View>: NSViewRepresentable {
    
    let canvas: GestureCanvas
    let contentBounds: CGRect?
    let tracksBackgroundPresses: Bool
    let preservesContentAnimations: Bool
    let content: () -> Content
    
    func makeNSView(context: Context) -> GestureCanvasTrackpadNSView {
        let contentView = context.coordinator.makeContentView(
            content(), preservesAnimations: preservesContentAnimations
        )
        let view = GestureCanvasTrackpadNSView(canvas: canvas, contentView: contentView)
        canvas.updateBounds(contentBounds, viewportSize: contentView.bounds.size)
        view.updateBackgroundPressTracking(tracksBackgroundPresses)
        return view
    }
    
    func updateNSView(_ trackpadView: GestureCanvasTrackpadNSView, context: Context) {
        context.coordinator.refresh(content(), transaction: context.transaction)
        canvas.updateBounds(contentBounds, viewportSize: trackpadView.viewportSize)
        trackpadView.updateBackgroundPressTracking(tracksBackgroundPresses)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    @MainActor
    final class Coordinator {

        private var hostingController: NSHostingController<Content>?
        private var animatedHostingController: NSHostingController<GestureCanvasHostingView<Content>>?

        func makeContentView(_ content: Content, preservesAnimations: Bool) -> NSView {
            if preservesAnimations {
                let hostedContent = GestureCanvasHostedContent(view: content)
                let controller = NSHostingController(rootView: GestureCanvasHostingView(content: hostedContent))
                animatedHostingController = controller
                return controller.view
            }
            let controller = NSHostingController(rootView: content)
            hostingController = controller
            return controller.view
        }

        func refresh(_ content: Content, transaction: Transaction) {
            if let animatedHostingController {
                animatedHostingController.rootView.content.update(content, transaction: transaction)
            } else {
                hostingController?.rootView = content
            }
        }
    }
}

#endif
