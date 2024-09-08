//
//  GestureCanvasInteractionView.swift
//  GestureCanvas
//
//  Created by Anton on 2024-09-08.
//

#if !os(macOS)

import UIKit
import Combine

final class GestureCanvasInteractionUIView: UIView {
    
    private var interaction: UIEditMenuInteraction?
    
    let canvas: GestureCanvas
    
    private let contentView: UIView
    
    private var cancelBag: Set<AnyCancellable> = []

    public init(canvas: GestureCanvas, contentView: UIView) {
    
        self.canvas = canvas
        self.contentView = contentView
    
        super.init(frame: .zero)
        
        layout()
        addGesture()
        listenForSetup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func layout() {
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(contentView)
        
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
    
    private func addGesture() {
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(didLongPress(_:)))
        longPress.allowedTouchTypes = [UITouch.TouchType.direct.rawValue as NSNumber]
        addGestureRecognizer(longPress)
    }
    
    private func listenForSetup() {
        canvas.interactionSetup
            .sink { [weak self] delegate in
                guard let self else { return }
                let interaction = UIEditMenuInteraction(delegate: delegate)
                addInteraction(interaction)
                self.interaction = interaction
            }
            .store(in: &cancelBag)
    }
    
    @objc private func didLongPress(_ recognizer: UIGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        let location: CGPoint = recognizer.location(in: contentView)
        canvas.lastInteractionLocation = location
        let configuration = UIEditMenuConfiguration(identifier: nil, sourcePoint: location)
        interaction?.presentEditMenu(with: configuration)
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}

#endif
