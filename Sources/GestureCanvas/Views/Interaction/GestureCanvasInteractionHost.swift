//
//  GestureCanvasInteractionHost.swift
//  GestureCanvas
//

#if !os(macOS)
import UIKit

/// Identifies the native ancestor that owns a canvas's gesture recognizers.
@MainActor
public protocol GestureCanvasInteractionHost: AnyObject {
    var gestureCanvasInteractionView: UIView { get }
}
#endif
