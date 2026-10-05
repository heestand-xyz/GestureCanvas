//
//  GestureCanvasInteractionView.swift
//  GestureCanvas
//
//  Created by Anton on 2024-09-08.
//

#if !os(macOS)

import SwiftUI
import UIKit

struct GestureCanvasInteractionView<Content: View>: UIViewRepresentable {
    
    let canvas: GestureCanvas
    let contentBounds: CGRect?
    let usesNativeScrolling: Bool
    let tracksBackgroundPresses: Bool
    let preservesContentAnimations: Bool
    let content: () -> Content
    
    func makeUIView(context: Context) -> GestureCanvasInteractionUIView {
        let contentView = context.coordinator.makeContentView(
            content(), preservesAnimations: preservesContentAnimations
        )
        contentView.backgroundColor = .clear
        let view = GestureCanvasInteractionUIView(canvas: canvas, contentView: contentView)
        canvas.updateBounds(contentBounds, viewportSize: contentView.bounds.size)
        view.updateScrollBounds(usesNativeScrolling ? contentBounds : nil)
        view.updateBackgroundPressTracking(tracksBackgroundPresses)
        return view
    }
    
    func updateUIView(_ interactionView: GestureCanvasInteractionUIView, context: Context) {
        context.coordinator.refresh(content(), transaction: context.transaction)
        canvas.updateBounds(contentBounds, viewportSize: interactionView.contentView.bounds.size)
        interactionView.updateScrollBounds(usesNativeScrolling ? contentBounds : nil)
        interactionView.updateBackgroundPressTracking(tracksBackgroundPresses)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    @MainActor
    final class Coordinator {

        private var hostingController: UIHostingController<Content>?
        private var animatedHostingController: UIHostingController<GestureCanvasHostingView<Content>>?

        func makeContentView(_ content: Content, preservesAnimations: Bool) -> UIView {
            if preservesAnimations {
                let hostedContent = GestureCanvasHostedContent(view: content)
                let controller = UIHostingController(rootView: GestureCanvasHostingView(content: hostedContent))
                animatedHostingController = controller
                return controller.view
            }
            let controller = UIHostingController(rootView: content)
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
