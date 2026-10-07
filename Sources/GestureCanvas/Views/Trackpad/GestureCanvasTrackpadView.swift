#if os(macOS)

import AppKit
import SwiftUI
import CoreGraphicsExtensions

struct GestureCanvasTrackpadView<Content: View>: NSViewRepresentable {
    
    let canvas: GestureCanvas
    let contentBounds: CGRect?
    let tracksBackgroundPresses: Bool
    let preservesContentAnimations: Bool
    let ignoresSafeArea: Bool
    let content: () -> Content
    
    func makeNSView(context: Context) -> GestureCanvasTrackpadNSView {
        let contentView = context.coordinator.makeContentView(
            content(), preservesAnimations: preservesContentAnimations, ignoresSafeArea: ignoresSafeArea
        )
        let view = GestureCanvasTrackpadNSView(canvas: canvas, contentView: contentView,
                                             ignoresSafeArea: ignoresSafeArea)
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

        func makeContentView(_ content: Content, preservesAnimations: Bool, ignoresSafeArea: Bool) -> NSView {
            if preservesAnimations {
                let hostedContent = GestureCanvasHostedContent(view: content)
                let controller = NSHostingController(rootView: GestureCanvasHostingView(content: hostedContent))
                if ignoresSafeArea { controller.safeAreaRegions = [] }
                animatedHostingController = controller
                return controller.view
            }
            let controller = NSHostingController(rootView: content)
            if ignoresSafeArea { controller.safeAreaRegions = [] }
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
