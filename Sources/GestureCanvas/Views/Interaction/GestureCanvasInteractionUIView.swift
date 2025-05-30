//
//  GestureCanvasInteractionView.swift
//  GestureCanvas
//
//  Created by Anton on 2024-09-08.
//

#if !os(macOS)

import UIKit
import Combine
import CoreGraphicsExtensions

final class GestureCanvasInteractionUIView: UIView {
    
    private var interaction: UIEditMenuInteraction?
    
    let canvas: GestureCanvas
    
    let contentView: UIView
    
    private var cancelBag: Set<AnyCancellable> = []
    
    struct Pinch {
        let location: CGPoint
        let coordinate: GestureCanvasCoordinate
    }
    private var startPinch: Pinch?

    public init(canvas: GestureCanvas, contentView: UIView) {
    
        self.canvas = canvas
        self.contentView = contentView
    
        super.init(frame: .zero)
        
        setup()
        layout()
        addGesture()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        guard let delegate: UIEditMenuInteractionDelegate = canvas.delegate?.gestureCanvasEditMenuInteractionDelegate() else { return }
        let interaction = UIEditMenuInteraction(delegate: delegate)
        addInteraction(interaction)
        self.interaction = interaction
    }
    
    private func layout() {
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(contentView)
        
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
        ])
    }
    
    private func addGesture() {
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(didLongPress(_:)))
        longPress.allowedTouchTypes = [UITouch.TouchType.direct.rawValue as NSNumber]
        addGestureRecognizer(longPress)
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(didPinch(_:)))
        pinch.delegate = self
        addGestureRecognizer(pinch)
    }
    
    @objc private func didLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }
        let location: CGPoint = recognizer.location(in: contentView)
        guard let mappedLocation: CGPoint = canvas.longPress(at: location) else { return }
        canvas.lastInteractionLocation = mappedLocation
        let configuration = UIEditMenuConfiguration(identifier: nil, sourcePoint: mappedLocation)
        interaction?.presentEditMenu(with: configuration)
    }
    
    @objc private func didPinch(_ recognizer: UIPinchGestureRecognizer) {
        func location() -> CGPoint {
            recognizer.location(in: self) + canvas.zoomCoordinateOffset
        }
        switch recognizer.state {
        case .possible:
            break
        case .began:
            guard canvas.delegate?.gestureCanvasAllowPinch(canvas) == true else { return }
            startPinch = Pinch(
                location: location(),
                coordinate: canvas.coordinate
            )
            if canvas.isPanning {
                canvas.isPanning = false
            }
            canvas.isZooming = true
        case .changed:
            guard recognizer.numberOfTouches == 2 else { break }
            guard let startPinch: Pinch else { break }
            var scale: CGFloat = startPinch.coordinate.scale * recognizer.scale
            if let minimumScale = canvas.minimumScale {
                scale = max(scale, minimumScale)
            }
            if let maximumScale = canvas.maximumScale {
                scale = min(scale, maximumScale)
            }
            let magnification: CGFloat = scale / startPinch.coordinate.scale
            let offset: CGPoint = location() - startPinch.location
            let locationOffset: CGPoint = startPinch.coordinate.offset - startPinch.location
            let scaledLocationOffset: CGPoint = locationOffset * magnification
            let scaleOffset: CGPoint = scaledLocationOffset - locationOffset
            var coordinate = canvas.coordinate
            coordinate.offset = startPinch.coordinate.offset + offset + scaleOffset
            coordinate.scale = scale
            canvas.move(to: coordinate)
        case .ended, .cancelled, .failed:
            guard startPinch != nil else { return }
            startPinch = nil
            canvas.isZooming = false
        @unknown default:
            break
        }
    }
}

extension GestureCanvasInteractionUIView: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
       true
    }
}

#endif
