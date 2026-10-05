import CoreGraphics

extension GestureCanvas {
    func isDragExcluded(at location: CGPoint) -> Bool {
        let point = CGPoint(x: location.x - zoomCoordinateOffset.x,
                            y: location.y - zoomCoordinateOffset.y)
        return dragExclusionPaths.values.contains { $0.contains(point) }
    }

    func interactionTap(at location: CGPoint, count: Int, keyboardFlags: Set<GestureCanvasKeyboardFlag>) -> Bool {
        guard !isInteractionDragging else { return true }
        return interactionDelegate?.gestureCanvas(self, tapAt: location, count: count, keyboardFlags: keyboardFlags) ?? false
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
        interactionDragLocations[id] = location
#if !os(macOS)
        scrollController?.interactionBegan()
#endif
        gestureStart()
        return true
    }

    func updateInteractionDrag(id: GestureCanvasDragID, at location: CGPoint) {
        guard interactionDragLocations[id] != nil else { return }
        interactionDragLocations[id] = location
        interactionDragDelegate?.gestureCanvas(self, updateDrag: id, at: location)
    }

    /// A held pointer stays in view space while panning changes its content position.
    func updateInteractionDragsForCoordinateChange() {
        guard isInteractionDragging, !isCancellingInteraction, !isUpdatingInteractionDrags else { return }
        isUpdatingInteractionDrags = true
        defer { isUpdatingInteractionDrags = false }
        // A delegate can end another drag or change the camera during an update.
        for id in Array(interactionDragLocations.keys) {
            guard let location = interactionDragLocations[id] else { continue }
            updateInteractionDrag(id: id, at: location)
        }
    }

    func endInteractionDrag(id: GestureCanvasDragID, at location: CGPoint) {
        guard interactionDragLocations.removeValue(forKey: id) != nil else { return }
        let delegate = interactionDragDelegate
        if interactionDragLocations.isEmpty {
            interactionDragDelegate = nil
        }
        delegate?.gestureCanvas(self, endDrag: id, at: location)
#if !os(macOS)
        scrollController?.interactionEnded()
#endif
        boundsController?.settleAfterInteraction()
    }

    /// Ends one drag without committing its action, leaving any other drag running.
    public func cancelInteractionDrag(id: GestureCanvasDragID) {
        guard interactionDragLocations.removeValue(forKey: id) != nil else { return }
        let delegate = interactionDragDelegate
        if interactionDragLocations.isEmpty {
            interactionDragDelegate = nil
        }
        delegate?.gestureCanvas(self, cancelDrag: id)
#if !os(macOS)
        scrollController?.interactionEnded()
#endif
        boundsController?.settleAfterInteraction()
    }

    /// Ends ownership of every current interaction without committing its action.
    /// Call before replacing a canvas's content or its interaction delegate.
    public func cancelInteraction() {
        cancelInteraction(preservingBackgroundPresses: false)
    }

    /// A zoom takes over editing without releasing physical background contacts.
    func cancelInteraction(preservingBackgroundPresses: Bool) {
#if os(macOS)
        tapKeyboardFlags = []
        setToolTip(nil)
#endif
        guard !isCancellingInteraction else { return }
        isCancellingInteraction = true
        defer { isCancellingInteraction = false }
        if !preservingBackgroundPresses {
            backgroundPressObserver?.cancelBackgroundPressTracking()
            updateBackgroundPress(false)
        }
        boundsController?.cancelSettlement()
#if !os(macOS)
        scrollController?.cancelScrolling()
#endif
        let delegate = interactionDragDelegate ?? interactionDelegate
        interactionDragLocations.removeAll()
        interactionDragDelegate = nil
        delegate?.gestureCanvasCancelInteraction(self)
        delegate?.gestureCanvas(self, hoverAt: nil)
    }

    func interactionHover(at location: CGPoint?) {
        interactionDelegate?.gestureCanvas(self, hoverAt: location)
    }
}
