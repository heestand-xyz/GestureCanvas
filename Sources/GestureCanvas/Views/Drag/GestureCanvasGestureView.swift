//
//  CanvasGestureView.swift
//  Space Flow
//
//  Created by Anton Heestand on 2024-03-20.
//

import SwiftUI
import CoreGraphicsExtensions

public struct GestureCanvasGestureView: View {
    
    @Bindable var canvas: GestureCanvas
    
    @State private var startCoordinate: GestureCanvasCoordinate?
    
    public init(canvas: GestureCanvas) {
        self.canvas = canvas
    }
    
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
            .simultaneousGesture(
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
#if !os(macOS)
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
#endif
    }
}
