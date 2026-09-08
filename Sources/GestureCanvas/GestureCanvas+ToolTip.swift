#if os(macOS)
import AppKit

extension GestureCanvas {
    public func setToolTip(_ tip: GestureCanvasToolTip?) {
        guard toolTip?.id != tip?.id || toolTip?.frame != tip?.frame else { return }
        toolTip = tip
        hasToolTip = tip != nil
        toolTipPresenter?.update()
    }
}
#endif
