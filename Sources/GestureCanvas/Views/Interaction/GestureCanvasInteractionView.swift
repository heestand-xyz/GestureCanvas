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
    let content: () -> Content
    
    func makeUIView(context: Context) -> GestureCanvasInteractionUIView {
        let hostingController = UIHostingController(rootView: content())
        context.coordinator.hostingController = hostingController
        let contentView: UIView = hostingController.view
        contentView.backgroundColor = .clear
        let view = GestureCanvasInteractionUIView(canvas: canvas, contentView: contentView)
        canvas.updateBounds(contentBounds, viewportSize: contentView.bounds.size)
        view.updateScrollBounds(usesNativeScrolling ? contentBounds : nil)
        return view
    }
    
    func updateUIView(_ interactionView: GestureCanvasInteractionUIView, context: Context) {
        context.coordinator.content = content
        context.coordinator.refresh()
        canvas.updateBounds(contentBounds, viewportSize: interactionView.contentView.bounds.size)
        interactionView.updateScrollBounds(usesNativeScrolling ? contentBounds : nil)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(content: content)
    }
    
    class Coordinator {

        var content: () -> Content

        var hostingController: UIHostingController<Content>?

        init(content: @escaping () -> Content) {
            self.content = content
        }

        func refresh() {
            // Needed to keep view models in sync with views.
            hostingController?.rootView = content()
        }
    }
}

#endif
