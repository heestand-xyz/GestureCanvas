#if !os(macOS)

import UIKit

/// An empty scrolling surface. Rendering and controls stay in the sibling hosting view.
final class GestureCanvasScrollUIView: UIScrollView {
    // Keep keyboard commands on the enclosing canvas, including after a touch scroll.
    override var canBecomeFirstResponder: Bool { false }
}

#endif
