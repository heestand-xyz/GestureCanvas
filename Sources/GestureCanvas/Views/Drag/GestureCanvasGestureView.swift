//
//  GestureCanvasGestureView.swift
//  GestureCanvas
//
//  Created by Anton Heestand on 2024-03-20.
//

import SwiftUI
import CoreGraphicsExtensions

public struct GestureCanvasGestureView: View {
    
    @Bindable var canvas: GestureCanvas
    
    @State private var startCoordinate: GestureCanvasCoordinate?
    
    public var body: some View {
        Color.gray.opacity(0.001)
            .coordinateSpace(GestureCanvasCoordinate.space)
            .gesture(
                SpatialTapGesture(count: 2)
                    .onEnded { value in
                        canvas.backgroundDoubleTap(at: value.location)
                    }
            )
            .gesture(
                SpatialTapGesture(count: 1)
                    .onEnded { value in
                        canvas.backgroundTap(at: value.location)
                    }
            )
            .highPriorityGesture(
                DragGesture()
                    .onChanged { value in
                        onDragChanged(value)
                    }
                    .onEnded { value in
                        onDragEnded(value)
                    }
            )
    }
    
    private func onDragChanged(_ value: DragGesture.Value) {
        if startCoordinate == nil {
#if os(macOS)
            canvas.dragSelectionStarted(at: value.startLocation)
#else
            if canvas.isZooming { return }
            canvas.isPanning = true
#endif
            startCoordinate = canvas.coordinate
        }
#if os(macOS)
        canvas.dragSelectionUpdated(at: value.location)
#else
        if canvas.isZooming {
            canvas.isPanning = false
            startCoordinate = nil
            return
        }
        canvas.offset(to: startCoordinate!.offset + value.translation)
#endif
    }
    
    private func onDragEnded(_ value: DragGesture.Value) {
        guard startCoordinate != nil else { return }
#if os(macOS)
        canvas.dragSelectionEnded(at: value.location)
#else
        canvas.isPanning = false
#endif
        startCoordinate = nil
    }
}
