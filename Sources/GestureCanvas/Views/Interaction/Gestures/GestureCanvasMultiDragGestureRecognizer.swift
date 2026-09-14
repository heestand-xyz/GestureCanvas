//
//  GestureCanvasMultiDragGestureRecognizer.swift
//  GestureCanvas
//

#if !os(macOS)

import UIKit
import CoreGraphicsExtensions

/// Drives one drag per touch, so a second finger starts its own drag
/// instead of joining the first one or turning the pair into a pinch.
///
/// A single SwiftUI drag gesture can only follow one touch sequence, so canvases
/// that route interactions hand every direct touch to this recognizer instead.
final class GestureCanvasMultiDragGestureRecognizer: UIGestureRecognizer {

    /// Matches the movement a SwiftUI drag gesture needs before it starts.
    var dragThreshold: CGFloat = 10

    private enum Mode {
        /// Below the drag threshold.
        case pending
        /// Dragging content through the interaction delegate.
        case interaction
        /// Moving the canvas itself.
        case pan
        /// Claimed by another gesture, or refused by its content.
        case ignored
    }

    private struct Track {
        let dragID: GestureCanvasDragID
        let startLocation: CGPoint
        /// The canvas offset when the touch landed, to follow content another touch pans away.
        let startCanvasOffset: CGPoint
        let isContent: Bool
        var mode: Mode
    }

    private let canvas: GestureCanvas
    private unowned let contentView: UIView

    private var tracks: [ObjectIdentifier: Track] = [:]
    private var panTouch: ObjectIdentifier?
    private var panStartCoordinate: GestureCanvasCoordinate?

    init(canvas: GestureCanvas, contentView: UIView) {
        self.canvas = canvas
        self.contentView = contentView
        super.init(target: nil, action: nil)
        // Taps, long presses and the double tap zoom stay reachable.
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }

    // MARK: - Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        for touch in touches where handles(touch) {
            let location = location(of: touch)
            tracks[ObjectIdentifier(touch)] = Track(
                dragID: GestureCanvasDragID(),
                startLocation: location,
                startCanvasOffset: canvas.coordinate.limited.offset,
                isContent: canvas.interactionHasContent(at: location),
                mode: canvas.isDragExcluded(at: location) ? .ignored : .pending
            )
        }
        canvas.ownsDirectTouches = !tracks.isEmpty
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        for touch in touches {
            let key = ObjectIdentifier(touch)
            guard var track: Track = tracks[key] else { continue }
            let location = location(of: touch)
            switch track.mode {
            case .pending:
                let offset: CGPoint = location - track.startLocation
                guard hypot(offset.x, offset.y) >= dragThreshold else { continue }
                track.mode = begin(track: track, at: location, key: key)
                tracks[key] = track
                if track.mode != .ignored, state == .possible {
                    state = .began
                }
            case .interaction:
                canvas.updateInteractionDrag(id: track.dragID, at: location)
                state = .changed
            case .pan:
                updatePan(track: track, at: location)
                state = .changed
            case .ignored:
                continue
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        finish(touches, cancelled: false)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        finish(touches, cancelled: true)
    }

    override func reset() {
        super.reset()
        // UIKit also resets after another gesture wins, with touches still tracked.
        releaseAllTracks()
    }

    private func releaseAllTracks() {
        let tracked = tracks.values
        tracks.removeAll()
        panTouch = nil
        panStartCoordinate = nil
        for track in tracked {
            switch track.mode {
            case .interaction:
                canvas.cancelInteractionDrag(id: track.dragID)
            case .pan:
                canvas.cancelPan()
            case .pending, .ignored:
                break
            }
        }
        canvas.ownsDirectTouches = false
    }

    // MARK: - Begin

    private func begin(track: Track, at location: CGPoint, key: ObjectIdentifier) -> Mode {
        guard !canvas.isZooming else { return .ignored }
        if track.isContent,
           canvas.beginInteractionDrag(id: track.dragID, at: contentStartLocation(of: track)) {
            canvas.updateInteractionDrag(id: track.dragID, at: location)
            return .interaction
        }
        guard panTouch == nil, !canvas.isSelecting else { return .ignored }
        panTouch = key
        panStartCoordinate = canvas.coordinate.unlimited
        canvas.startPan(at: track.startLocation)
        canvas.gestureStart()
        updatePan(track: track, at: location)
        return .pan
    }

    /// Another touch may have panned the canvas since this one landed.
    /// Content moved with it, so the hit test has to move with it too.
    private func contentStartLocation(of track: Track) -> CGPoint {
        track.startLocation + (canvas.coordinate.limited.offset - track.startCanvasOffset)
    }

    // MARK: - Pan

    private func updatePan(track: Track, at location: CGPoint) {
        guard !canvas.isZooming, let panStartCoordinate else { return }
        let offset: CGPoint = location - track.startLocation
        canvas.offset(to: panStartCoordinate.offset + offset)
        canvas.updatePan(at: location)
    }

    // MARK: - Finish

    private func finish(_ touches: Set<UITouch>, cancelled: Bool) {
        for touch in touches {
            let key = ObjectIdentifier(touch)
            guard let track: Track = tracks.removeValue(forKey: key) else { continue }
            let location = location(of: touch)
            switch track.mode {
            case .interaction:
                if cancelled {
                    canvas.cancelInteractionDrag(id: track.dragID)
                } else {
                    canvas.endInteractionDrag(id: track.dragID, at: location)
                }
            case .pan:
                panTouch = nil
                panStartCoordinate = nil
                if cancelled {
                    canvas.cancelPan()
                } else {
                    canvas.endPan(at: location)
                }
            case .pending, .ignored:
                break
            }
        }
        guard tracks.isEmpty else { return }
        canvas.ownsDirectTouches = false
        switch state {
        case .began, .changed:
            state = cancelled ? .cancelled : .ended
        default:
            state = .failed
        }
    }

    // MARK: - Touch

    private func handles(_ touch: UITouch) -> Bool {
        // Canvases without content to hit keep their single SwiftUI drag gesture.
        guard canvas.routesInteractions else { return false }
#if os(iOS)
        // An indirect pointer keeps the trackpad's own pan and marquee selection.
        return touch.type == .direct
#else
        return true
#endif
    }

    private func location(of touch: UITouch) -> CGPoint {
        touch.location(in: contentView) + canvas.zoomCoordinateOffset
    }
}

#endif
