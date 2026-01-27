//
//  GestureCanvasDynamicCoordinate.swift
//  GestureCanvas
//
//  Created by Anton Heestand on 2026-01-27.
//

public enum GestureCanvasDynamicCoordinate: Sendable, Equatable {
    case unlimited(GestureCanvasCoordinate)
    case limited(
        GestureCanvasCoordinate,
        unlimited: GestureCanvasCoordinate
    )
}

extension GestureCanvasDynamicCoordinate {
    public var unlimited: GestureCanvasCoordinate {
        switch self {
        case .unlimited(let unlimitedCoordinate):
            return unlimitedCoordinate
        case .limited(_, let unlimitedCoordinate):
            return unlimitedCoordinate
        }
    }
    
    public var limited: GestureCanvasCoordinate {
        switch self {
        case .unlimited(let unlimitedCoordinate):
            return unlimitedCoordinate
        case .limited(let limitedCoordinate, _):
            return limitedCoordinate
        }
    }
}
