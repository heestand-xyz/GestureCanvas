#if !os(macOS)

import CoreGraphics

/// The camera may center on any point inside the visible content rectangle.
/// Half a viewport of padding on each side makes its edges reachable at the center,
/// independently of the content's aspect ratio and the current zoom scale.
struct GestureCanvasScrollGeometry: Equatable {
    let contentSize: CGSize
    let cameraOrigin: CGPoint

    init(contentBounds: CGRect, scale: CGFloat, viewportSize: CGSize) {
        precondition(scale.isFinite && scale > 0)
        precondition(!contentBounds.isNull && !contentBounds.isInfinite)
        precondition(viewportSize.width > 0 && viewportSize.height > 0)
        let bounds = contentBounds.standardized
        contentSize = CGSize(
            width: bounds.width * scale + viewportSize.width,
            height: bounds.height * scale + viewportSize.height
        )
        cameraOrigin = CGPoint(
            x: viewportSize.width / 2 - bounds.minX * scale,
            y: viewportSize.height / 2 - bounds.minY * scale
        )
    }

    func contentOffset(for cameraOffset: CGPoint) -> CGPoint {
        CGPoint(x: cameraOrigin.x - cameraOffset.x, y: cameraOrigin.y - cameraOffset.y)
    }

    func cameraOffset(for contentOffset: CGPoint) -> CGPoint {
        CGPoint(x: cameraOrigin.x - contentOffset.x, y: cameraOrigin.y - contentOffset.y)
    }

    func clamped(_ contentOffset: CGPoint, viewportSize: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(contentOffset.x, 0), contentSize.width - viewportSize.width),
            y: min(max(contentOffset.y, 0), contentSize.height - viewportSize.height)
        )
    }

    func rubberBanded(_ contentOffset: CGPoint, viewportSize: CGSize) -> CGPoint {
        let edge = clamped(contentOffset, viewportSize: viewportSize)
        return CGPoint(
            x: edge.x + tension(contentOffset.x - edge.x, length: viewportSize.width),
            y: edge.y + tension(contentOffset.y - edge.y, length: viewportSize.height)
        )
    }

    private func tension(_ distance: CGFloat, length: CGFloat) -> CGFloat {
        let magnitude = abs(distance)
        let resisted = (0.55 * magnitude * length) / (length + 0.55 * magnitude)
        return distance < 0 ? -resisted : resisted
    }
}

#endif
