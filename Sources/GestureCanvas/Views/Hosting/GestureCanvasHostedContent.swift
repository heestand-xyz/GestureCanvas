import Observation
import SwiftUI

/// Carries updates across the native hosting boundary without replacing its root.
@MainActor
@Observable
final class GestureCanvasHostedContent<Content: View> {
    var view: Content

    init(view: Content) {
        self.view = view
    }

    func update(_ view: Content, transaction: Transaction) {
        withTransaction(transaction) {
            self.view = view
        }
    }
}
