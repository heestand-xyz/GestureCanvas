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
                        if startCoordinate == nil {
#if os(macOS)
                            canvas.dragSelectionStarted(at: value.startLocation)
#endif
                            startCoordinate = canvas.coordinate
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
#endif
                        startCoordinate = nil
                    }
            )
    }
}
