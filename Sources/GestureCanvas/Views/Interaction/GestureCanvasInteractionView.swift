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
    let content: () -> Content
    
    func makeUIView(context: Context) -> GestureCanvasInteractionUIView {
        let hostingController = UIHostingController(rootView: content())
        context.coordinator.hostingController = hostingController
        let contentView: UIView = hostingController.view
        contentView.backgroundColor = .clear
        return GestureCanvasInteractionUIView(canvas: canvas, contentView: contentView)
    }
    
    func updateUIView(_ interactionView: GestureCanvasInteractionUIView, context: Context) {
        context.coordinator.refresh()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(content: content)
    }
    
    class Coordinator {

        private let content: () -> Content

        var hostingController: UIHostingController<Content>?

        init(content: @escaping () -> Content) {
            self.content = content
        }

        func refresh() {
            print("Gesture Canvas - Refresh")
            hostingController?.rootView = content()
        }
    }
}

#endif
