#if !os(macOS)

import UIKit
import CoreGraphicsExtensions

@MainActor
final class GestureCanvasScrollController: NSObject {
    let scrollView = GestureCanvasScrollUIView()
    private unowned let canvas: GestureCanvas
    private unowned let contentView: UIView
    private var contentBounds: CGRect
    private var geometry: GestureCanvasBoundsGeometry?
    private var needsBoundsLayout = true
    private var isSynchronizing = false
    private var isApplyingScroll = false
    private var ownsPan = false
    private var lastPanLocation: CGPoint = .zero
    private(set) var isSuspended = false

    init(canvas: GestureCanvas, contentView: UIView, contentBounds: CGRect) {
        self.canvas = canvas
        self.contentView = contentView
        self.contentBounds = contentBounds
        super.init()
        scrollView.backgroundColor = .clear
        scrollView.isDirectionalLockEnabled = false
        scrollView.isPagingEnabled = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.scrollsToTop = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.delaysContentTouches = false
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 1
        scrollView.panGestureRecognizer.allowedScrollTypesMask = .all
        scrollView.delegate = self
        scrollView.panGestureRecognizer.addTarget(self, action: #selector(panChanged(_:)))
    }

    func update(contentBounds: CGRect) {
        guard self.contentBounds != contentBounds else { return }
        self.contentBounds = contentBounds
        needsBoundsLayout = true
        scrollView.superview?.setNeedsLayout()
    }

    func layout(in frame: CGRect) {
        let resized = scrollView.bounds.size != frame.size
        if resized {
            cancelScrolling()
        }
        isSynchronizing = true
        scrollView.frame = frame
        isSynchronizing = false
        guard !isSuspended else { return }
        if resized {
            // The app's onGeometryChange owns camera recentering. In particular,
            // do not clamp using the old camera before its resize offset arrives.
            synchronize(clamp: false)
            return
        }
        layout()
    }

    private func layout() {
        guard !isSuspended else { return }
        // Updating a moving folder's extents must not rebase UIKit's active pan.
        guard !canvas.isInteractionDragging, !ownsPan else { return }
        guard needsBoundsLayout else { return }
        // A node drop can shrink the folder while its final move is still being
        // committed asynchronously. Rebase the scroll geometry, never the camera:
        // clamping here would move the released node or change its committed position.
        // Settlement waits for the commit before animating the viewport back.
        synchronize(clamp: false)
    }

    func coordinateChanged() {
        guard !isApplyingScroll, !isSynchronizing, !isSuspended else { return }
        // Keyboard navigation, fit-to-content and app animations still own the camera.
        // Synchronize their exact position without feeding it back through the delegate.
        if scrollView.isDecelerating {
            cancelScrolling()
        }
        synchronize(clamp: false)
    }

    func interactionBegan() {
        canvas.boundsController?.cancelSettlement()
        // Stop a previous fling, but keep an explicitly held background pan alive.
        if scrollView.isDecelerating {
            cancelScrolling()
        }
    }

    func interactionEnded() {
        guard !canvas.isInteractionDragging else { return }
        refreshBounds()
        scrollView.superview?.setNeedsLayout()
    }

    func suspendForZoom() {
        isSuspended = true
        cancelScrolling()
        scrollView.isScrollEnabled = false
        refreshBounds()
    }

    func resumeAfterZoom(clamp: Bool) {
        refreshBounds()
        isSuspended = false
        synchronize(clamp: clamp && !canvas.isAnimating)
        scrollView.isScrollEnabled = true
        scrollView.panGestureRecognizer.isEnabled = true
    }

    func cancelScrolling() {
        canvas.boundsController?.cancelSettlement()
        // Stopping a bounce can clamp UIKit's offset. Never publish that clamp to
        // the camera: a pinch must start at precisely the displayed coordinate.
        let wasSynchronizing = isSynchronizing
        isSynchronizing = true
        let offset = scrollView.contentOffset
        scrollView.panGestureRecognizer.isEnabled = false
        if #available(anyAppleOS 26.0, *) {
            scrollView.stopScrollingAndZooming()
        }
        scrollView.setContentOffset(offset, animated: false)
        scrollView.panGestureRecognizer.isEnabled = !isSuspended
        isSynchronizing = wasSynchronizing
        if ownsPan {
            ownsPan = false
            canvas.cancelPan()
        }
    }

    func detach() {
        cancelScrolling()
        scrollView.delegate = nil
        scrollView.removeFromSuperview()
        if canvas.scrollController === self {
            canvas.scrollController = nil
        }
    }

    private func refreshBounds() {
        if let bounds = canvas.delegate?.gestureCanvasBounds(canvas) {
            update(contentBounds: bounds)
        }
    }

    private func synchronize(clamp: Bool) {
        let size = scrollView.bounds.size
        guard size.width > 0, size.height > 0 else { return }
        let coordinate = canvas.coordinate.limited
        let geometry = GestureCanvasBoundsGeometry(
            contentBounds: contentBounds,
            scale: coordinate.scale,
            viewportSize: size
        )
        let requestedOffset = geometry.contentOffset(for: coordinate.offset)
        let offset = clamp ? geometry.clamped(requestedOffset, viewportSize: size) : requestedOffset
        isSynchronizing = true
        defer { isSynchronizing = false }
        self.geometry = geometry
        needsBoundsLayout = false
        if scrollView.contentSize != geometry.contentSize {
            scrollView.contentSize = geometry.contentSize
        }
        if scrollView.contentOffset != offset {
            scrollView.contentOffset = offset
        }
        if clamp, offset != requestedOffset {
            canvas.offset(to: geometry.cameraOffset(for: offset))
        }
    }

    private var panLocation: CGPoint {
        scrollView.panGestureRecognizer.location(in: contentView) + canvas.zoomCoordinateOffset
    }

    @objc private func panChanged(_ recognizer: UIPanGestureRecognizer) {
        guard !isSynchronizing, !isSuspended else { return }
        switch recognizer.state {
        case .began, .changed:
            lastPanLocation = panLocation
            if ownsPan {
                canvas.updatePan(at: lastPanLocation)
            }
        case .cancelled, .failed:
            if ownsPan {
                ownsPan = false
                canvas.cancelPan()
                layout()
            }
        default:
            break
        }
    }

    private func finishPan() {
        guard ownsPan else { return }
        ownsPan = false
        canvas.endPan(at: lastPanLocation)
        refreshBounds()
        layout()
    }


}

// MARK: - Scroll Delegate

extension GestureCanvasScrollController: UIScrollViewDelegate {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard !isSuspended, !isSynchronizing else { return }
        canvas.boundsController?.cancelSettlement()
        canvas.gestureStart()
        lastPanLocation = panLocation
        if !ownsPan {
            ownsPan = true
            canvas.startPan(at: lastPanLocation)
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard ownsPan, !isSuspended, !isSynchronizing, let geometry else { return }
        isApplyingScroll = true
        defer { isApplyingScroll = false }
        canvas.offset(to: geometry.cameraOffset(for: scrollView.contentOffset))
        if ownsPan {
            canvas.updatePan(at: lastPanLocation)
        }
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard !isSynchronizing, !isSuspended else { return }
        if !decelerate {
            finishPan()
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard !isSynchronizing, !isSuspended else { return }
        finishPan()
    }
}

#endif
