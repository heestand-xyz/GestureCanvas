//
//  CanvasPathGrid.swift
//  CanvasDemo
//
//  Created by Anton Heestand on 2021-03-01.
//

import SwiftUI
import CoreGraphicsExtensions

public struct GestureCanvasGrid: View {
    
    private let size: CGFloat
    private let style: GestureCanvasGridStyle
    private let coordinate: GestureCanvasCoordinate
    
    public init(
        size: CGFloat,
        style: GestureCanvasGridStyle = .one,
        coordinate: GestureCanvasCoordinate
    ) {
        self.size = size
        self.style = style
        self.coordinate = coordinate
    }
    
    private var spacing: CGFloat {
        size * coordinate.scale
    }
    
    public var body: some View {
        ZStack {
            switch style {
            case .one:
                grid(at: 1.0)
            case .fractions(let fractions):
                ForEach(fractions, id: \.self) { fraction in
                    if coordinate.scale > (0.25 / fraction) {
                        grid(at: fraction)
                            .opacity(Double((coordinate.scale - (0.25 / fraction)) * fraction))
                    }
                }
            }
        }
        .drawingGroup()
    }
    
    private func grid(
        at superScale: CGFloat,
        lineWidth: CGFloat = .pointsPerPixel
    ) -> some View {
        GeometryReader { geo in
            Path { path in
                for x in 0...xCount(size: geo.size, at: superScale) {
                    let offset: CGFloat = coordinate.offset.x.truncatingRemainder(dividingBy: spacing * superScale) + CGFloat(x) * spacing * superScale
                    path.move(to: CGPoint(x: offset, y: 0.0))
                    path.addLine(to: CGPoint(x: offset, y: geo.size.height))
                }
                for y in 0...yCount(size: geo.size, at: superScale) {
                    let offset: CGFloat = coordinate.offset.y.truncatingRemainder(dividingBy: spacing * superScale) + CGFloat(y) * spacing * superScale
                    path.move(to: CGPoint(x: 0.0, y: offset))
                    path.addLine(to: CGPoint(x: geo.size.width, y: offset))
                }
            }
            .stroke()
        }
    }
    
    private func xCount(
        size: CGSize,
        at superScale: CGFloat
    ) -> Int {
        let scaledSize: CGFloat = size.width / (spacing * superScale)
        return Int(ceil(scaledSize))
    }
    
    private func yCount(
        size: CGSize,
        at superScale: CGFloat
    ) -> Int {
        let scaledSize: CGFloat = size.height / (spacing * superScale)
        return Int(ceil(scaledSize))
    }
}
