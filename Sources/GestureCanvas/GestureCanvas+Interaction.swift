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

    /// Content under a touch that has not started to move yet.
    func interactionHasContent(at location: CGPoint) -> Bool {
        interactionDelegate?.gestureCanvas(self, hasContentAt: location) ?? false
    }

    func beginInteractionDrag(id: GestureCanvasDragID, at location: CGPoint) -> Bool {
#if os(macOS)
        setToolTip(nil)
#endif
        guard !isZooming,
              let interactionDelegate,
              interactionDelegate.gestureCanvas(self, beginDrag: id, at: location) else { return false }
        interactionDragDelegate = interactionDelegate
        interactionDragIDs.insert(id)
        gestureStart()
        return true
    }

    func updateInteractionDrag(id: GestureCanvasDragID, at location: CGPoint) {
        guard interactionDragIDs.contains(id) else { return }
        interactionDragDelegate?.gestureCanvas(self, updateDrag: id, at: location)
    }

    func endInteractionDrag(id: GestureCanvasDragID, at location: CGPoint) {
        guard interactionDragIDs.remove(id) != nil else { return }
        let delegate = interactionDragDelegate
        if interactionDragIDs.isEmpty {
            interactionDragDelegate = nil
        }
        delegate?.gestureCanvas(self, endDrag: id, at: location)
    }

    /// Ends one drag without committing its action, leaving any other drag running.
    public func cancelInteractionDrag(id: GestureCanvasDragID) {
        guard interactionDragIDs.remove(id) != nil else { return }
        let delegate = interactionDragDelegate
        if interactionDragIDs.isEmpty {
            interactionDragDelegate = nil
        }
        delegate?.gestureCanvas(self, cancelDrag: id)
    }

    /// Ends ownership of every current interaction without committing its action.
    /// Call before replacing a canvas's content or its interaction delegate.
    public func cancelInteraction() {
#if os(macOS)
        setToolTip(nil)
#endif
        guard !isCancellingInteraction else { return }
        isCancellingInteraction = true
        defer { isCancellingInteraction = false }
        let delegate = interactionDragDelegate ?? interactionDelegate
        interactionDragIDs.removeAll()
        interactionDragDelegate = nil
        delegate?.gestureCanvasCancelInteraction(self)
        delegate?.gestureCanvas(self, hoverAt: nil)
    }

    func interactionHover(at location: CGPoint?) {
        interactionDelegate?.gestureCanvas(self, hoverAt: location)
    }
}
