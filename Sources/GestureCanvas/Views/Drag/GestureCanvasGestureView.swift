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
    
    @State private var asSelection: Bool = false
    
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
            .onChange(of: canvas.isZooming) { _, isZooming in
                if startCoordinate != nil, isZooming {
                    canvas.cancelPan()
                    startCoordinate = nil
                }
            }
    }
    
    private func onDragChanged(_ value: DragGesture.Value) {
        if startCoordinate == nil {
            asSelection = {
#if os(macOS)
                true
#elseif os(iOS)
                canvas.isIndirectTouching
#else
                false
#endif
            }()
            if asSelection {
                canvas.dragSelectionStarted(at: value.startLocation)
            } else {
                if canvas.isZooming { return }
                if canvas.isSelecting { return }
                canvas.startPan(at: value.startLocation)
            }
            startCoordinate = canvas.coordinate.unlimited
        }
        if asSelection {
            canvas.dragSelectionUpdated(at: value.location)
        } else {
            if canvas.isZooming { return }
            if canvas.isSelecting { return }
            canvas.offset(to: startCoordinate!.offset + value.translation)
            canvas.updatePan(at: value.location)
        }
    }
    
    private func onDragEnded(_ value: DragGesture.Value) {
        defer {
            asSelection = false
        }
        guard startCoordinate != nil else { return }
        if asSelection {
            canvas.dragSelectionEnded(at: value.location)
        } else {
            canvas.endPan(at: value.location)
        }
        startCoordinate = nil
    }
}
