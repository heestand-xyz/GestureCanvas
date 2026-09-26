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
    @State private var dragID: GestureCanvasDragID?
    @GestureState private var isDragActive: Bool = false
    
    public var body: some View {
        Color.gray.opacity(0.001)
#if os(macOS)
            .gesture(
                SpatialTapGesture(count: 2, coordinateSpace: GestureCanvasCoordinate.space)
                    .onEnded { value in
                        let location = value.location + canvas.zoomCoordinateOffset
                        if !canvas.interactionTap(at: location, count: 2, keyboardFlags: canvas.tapKeyboardFlags) {
                            canvas.backgroundDoubleTap(at: location)
                        }
                    },
                including: canvas.routesInteractions ? .none : .all
            )
            .gesture(
                SpatialTapGesture(count: 1, coordinateSpace: GestureCanvasCoordinate.space)
                    .onEnded { value in
                        let location = value.location + canvas.zoomCoordinateOffset
                        if !canvas.interactionTap(at: location, count: 1, keyboardFlags: canvas.tapKeyboardFlags) {
                            canvas.backgroundTap(at: location)
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
                        SpatialTapGesture(count: 2, coordinateSpace: GestureCanvasCoordinate.space)
                            .onEnded { value in
                                let location = value.location + canvas.zoomCoordinateOffset
                                if !canvas.interactionTap(at: location, count: 2, keyboardFlags: canvas.tapKeyboardFlags) {
                                    canvas.backgroundDoubleTap(at: location)
                                }
                            }
                            .exclusively(before:
                                SpatialTapGesture(count: 1, coordinateSpace: GestureCanvasCoordinate.space)
                                    .onEnded { value in
                                        let location = value.location + canvas.zoomCoordinateOffset
                                        if !canvas.interactionTap(at: location, count: 1, keyboardFlags: canvas.tapKeyboardFlags) {
                                            canvas.backgroundTap(at: location)
                                        }
                                    }
                            )
                    ),
                including: canvas.routesInteractions ? .all : .none
            )
#endif
            .highPriorityGesture(
                DragGesture(coordinateSpace: GestureCanvasCoordinate.space)
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
                    cancelObjectDrag()
                }
                if startCoordinate != nil, isZooming {
                    canvas.cancelPan()
                    startCoordinate = nil
                }
            }
            .onChange(of: isDragActive) { _, isActive in
                if !isActive, isObjectDragging {
                    cancelObjectDrag()
                }
            }
            .onDisappear {
                if isObjectDragging {
                    cancelObjectDrag()
                }
            }
    }
    
    /// Direct touches belong to the multi drag recognizer, one drag each.
    private var isSupersededByMultiDrag: Bool {
#if os(macOS)
        false
#else
        canvas.ownsDirectTouches
#endif
    }

    private func onDragChanged(_ value: DragGesture.Value) {
        guard !isSupersededByMultiDrag else { return }
        // This space belongs to the hosted content, already inset by UIKit/AppKit.
        // Subtracting the outer safe area again shifts hits down and right.
        let location = value.location + canvas.zoomCoordinateOffset
        let startLocation = value.startLocation + canvas.zoomCoordinateOffset
        if isObjectDragging {
            if let dragID {
                canvas.updateInteractionDrag(id: dragID, at: location)
            }
            return
        }
        if startCoordinate == nil {
            guard !canvas.isDragExcluded(at: startLocation) else { return }
            let newDragID = GestureCanvasDragID()
            if !canvas.isZooming,
               canvas.beginInteractionDrag(id: newDragID, at: startLocation) {
                isObjectDragging = true
                dragID = newDragID
                canvas.updateInteractionDrag(id: newDragID, at: location)
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
                canvas.dragSelectionStarted(at: startLocation)
            } else {
                if canvas.isZooming { return }
                if canvas.isSelecting { return }
                canvas.startPan(at: startLocation)
            }
            startCoordinate = canvas.gestureStartCoordinate
        }
        if asSelection {
            canvas.dragSelectionUpdated(at: location)
        } else {
            if canvas.isZooming { return }
            if canvas.isSelecting { return }
            canvas.gestureUpdate(to: GestureCanvasCoordinate(
                offset: startCoordinate!.offset + value.translation, scale: startCoordinate!.scale
            ), at: location)
            canvas.updatePan(at: location)
        }
    }
    
    private func cancelObjectDrag() {
        if let dragID {
            canvas.cancelInteractionDrag(id: dragID)
        }
        dragID = nil
        isObjectDragging = false
    }
    
    private func onDragEnded(_ value: DragGesture.Value) {
        guard !isSupersededByMultiDrag else { return }
        let location = value.location + canvas.zoomCoordinateOffset
        if isObjectDragging {
            if let dragID {
                canvas.endInteractionDrag(id: dragID, at: location)
            }
            dragID = nil
            isObjectDragging = false
            return
        }
        defer {
            asSelection = false
        }
        guard startCoordinate != nil else { return }
        if asSelection {
            canvas.dragSelectionEnded(at: location)
        } else {
            canvas.endPan(at: location)
        }
        startCoordinate = nil
    }
}
