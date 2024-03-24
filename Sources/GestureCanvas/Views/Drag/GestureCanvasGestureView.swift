//
//  CanvasGestureView.swift
//  Space Flow
//
//  Created by Heestand, Anton Norman | Anton | GSSD on 2024-03-20.
//

import SwiftUI
import CoreGraphicsExtensions

struct GestureCanvasGestureView: View {
    
    @Bindable var canvas: GestureCanvas
    
    @State private var startCoordinate: GestureCanvasCoordinate?
    
    var body: some View {
        Color.gray.opacity(0.001)
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        if startCoordinate == nil {
#if os(macOS)
                            canvas.dragSelectionStarted(at: value.location)
#else
                            startCoordinate = canvas.coordinate
#endif
                        }
#if os(macOS)
                        canvas.dragSelectionUpdated(at: value.location)
#else
                        canvas.coordinate.offset = startCoordinate!.offset + value.translation
#endif
                    }
                    .onEnded { value in
#if os(macOS)
                        canvas.dragSelectionEnded(at: value.location)
#else
                        startCoordinate = nil
#endif
                    }
            )
            .gesture(
                MagnifyGesture()
                    .onChanged { value in
                        if startCoordinate == nil {
                            startCoordinate = canvas.coordinate
                        }
                        var scale: CGFloat = startCoordinate!.scale * value.magnification
                        scale = min(max(scale, canvas.minimumScale), canvas.maximumScale)
                        canvas.coordinate.scale = scale
                        let magnification: CGFloat = scale / startCoordinate!.scale
                        canvas.coordinate.offset = (startCoordinate!.offset - value.startLocation) * magnification + value.startLocation
                    }
                    .onEnded { _ in
                        startCoordinate = nil
                    }
            )
    }
}
