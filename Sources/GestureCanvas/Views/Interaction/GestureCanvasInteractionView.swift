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
        let contentView: UIView = hostingController.view
        contentView.backgroundColor = .clear // .gray.withAlphaComponent(0.001)
        return GestureCanvasInteractionUIView(canvas: canvas, contentView: contentView)
    }
    
    func updateUIView(_ trackpadView: GestureCanvasInteractionUIView, context: Context) {}
}

#endif
