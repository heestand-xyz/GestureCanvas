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

    @State private var isObjectDragging: Bool = false
    @GestureState private var isDragActive: Bool = false
    
    public var body: some View {
        Color.gray.opacity(0.001)
            .coordinateSpace(GestureCanvasCoordinate.space)
#if os(macOS)
            .gesture(
                SpatialTapGesture(count: 2)
                    .onEnded { value in
                        if !canvas.interactionTap(at: value.location, count: 2) {
                            canvas.backgroundDoubleTap(at: value.location)
                        }
                    },
                including: canvas.routesInteractions ? .none : .all
            )
            .gesture(
                SpatialTapGesture(count: 1)
                    .onEnded { value in
                        if !canvas.interactionTap(at: value.location, count: 1) {
                            canvas.backgroundTap(at: value.location)
                        }
                    },
                including: canvas.routesInteractions ? .none : .all
            )
            .gesture(
                LongPressGesture()
                    .onEnded { _ in
                        if let location = canvas.mouseLocation {
                            _ = canvas.interactionLongPress(at: location)
                        }
                    }
                    .exclusively(before:
                        SpatialTapGesture(count: 2)
                            .onEnded { value in
                                if !canvas.interactionTap(at: value.location, count: 2) {
                                    canvas.backgroundDoubleTap(at: value.location)
                                }
                            }
                            .exclusively(before:
                                SpatialTapGesture(count: 1)
                                    .onEnded { value in
                                        if !canvas.interactionTap(at: value.location, count: 1) {
                                            canvas.backgroundTap(at: value.location)
                                        }
                                    }
                            )
                    ),
                including: canvas.routesInteractions ? .all : .none
            )
#endif
            .highPriorityGesture(
                DragGesture()
                    .updating($isDragActive) { _, active, _ in
                        active = true
                    }
                    .onChanged { value in
                        onDragChanged(value)
                    }
                    .onEnded { value in
                        onDragEnded(value)
                    }
            )
            .onChange(of: canvas.isZooming) { _, isZooming in
                if isObjectDragging, isZooming {
                    canvas.cancelInteraction()
                }
                if startCoordinate != nil, isZooming {
                    canvas.cancelPan()
                    startCoordinate = nil
                }
            }
            .onChange(of: isDragActive) { _, isActive in
                if !isActive, isObjectDragging {
                    canvas.cancelInteraction()
                    isObjectDragging = false
                }
            }
            .onDisappear {
                if isObjectDragging {
                    canvas.cancelInteraction()
                    isObjectDragging = false
                }
            }
    }
    
    private func onDragChanged(_ value: DragGesture.Value) {
        if isObjectDragging {
            canvas.updateInteractionDrag(at: value.location - canvas.safeAreaOffset)
            return
        }
        if startCoordinate == nil {
            if !canvas.isZooming,
               canvas.beginInteractionDrag(at: value.startLocation - canvas.safeAreaOffset) {
                isObjectDragging = true
                canvas.updateInteractionDrag(at: value.location - canvas.safeAreaOffset)
                return
            }
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
                canvas.dragSelectionStarted(at: value.startLocation - canvas.safeAreaOffset)
            } else {
                if canvas.isZooming { return }
                if canvas.isSelecting { return }
                canvas.startPan(at: value.startLocation - canvas.safeAreaOffset)
            }
            startCoordinate = canvas.coordinate.unlimited
        }
        if asSelection {
            canvas.dragSelectionUpdated(at: value.location - canvas.safeAreaOffset)
        } else {
            if canvas.isZooming { return }
            if canvas.isSelecting { return }
            canvas.offset(to: startCoordinate!.offset + value.translation)
            canvas.updatePan(at: value.location - canvas.safeAreaOffset)
        }
    }
    
    private func onDragEnded(_ value: DragGesture.Value) {
        if isObjectDragging {
            canvas.endInteractionDrag(at: value.location - canvas.safeAreaOffset)
            isObjectDragging = false
            return
        }
        defer {
            asSelection = false
        }
        guard startCoordinate != nil else { return }
        if asSelection {
            canvas.dragSelectionEnded(at: value.location - canvas.safeAreaOffset)
        } else {
            canvas.endPan(at: value.location - canvas.safeAreaOffset)
        }
        startCoordinate = nil
    }
}
