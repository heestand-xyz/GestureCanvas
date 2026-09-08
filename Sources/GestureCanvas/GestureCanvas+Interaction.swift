import CoreGraphics

extension GestureCanvas {
    func interactionTap(at location: CGPoint, count: Int) -> Bool {
        guard !isInteractionDragging else { return true }
        return interactionDelegate?.gestureCanvas(self, tapAt: location, count: count) ?? false
    }

    func interactionLongPress(at location: CGPoint) -> Bool {
        guard !isInteractionDragging else { return true }
        return interactionDelegate?.gestureCanvas(self, longPressAt: location) ?? false
    }

    func beginInteractionDrag(at location: CGPoint) -> Bool {
#if os(macOS)
        setToolTip(nil)
#endif
        guard !isZooming, !isPanning, !isSelecting,
              let interactionDelegate,
              interactionDelegate.gestureCanvas(self, beginDragAt: location) else { return false }
        interactionDragDelegate = interactionDelegate
        isInteractionDragging = true
        gestureStart()
        return true
    }

    func updateInteractionDrag(at location: CGPoint) {
        guard isInteractionDragging else { return }
        interactionDragDelegate?.gestureCanvas(self, updateDragAt: location)
    }

    func endInteractionDrag(at location: CGPoint) {
        guard isInteractionDragging else { return }
        let delegate = interactionDragDelegate
        isInteractionDragging = false
        interactionDragDelegate = nil
        delegate?.gestureCanvas(self, endDragAt: location)
    }

    /// Ends ownership of the current interaction without committing its action.
    /// Call before replacing a canvas's content or its interaction delegate.
    public func cancelInteraction() {
#if os(macOS)
        setToolTip(nil)
#endif
        guard !isCancellingInteraction else { return }
        isCancellingInteraction = true
        defer { isCancellingInteraction = false }
        let delegate = interactionDragDelegate ?? interactionDelegate
        isInteractionDragging = false
        interactionDragDelegate = nil
        delegate?.gestureCanvasCancelInteraction(self)
        delegate?.gestureCanvas(self, hoverAt: nil)
    }

    func interactionHover(at location: CGPoint?) {
        interactionDelegate?.gestureCanvas(self, hoverAt: location)
    }
}
