import SwiftUI

@MainActor
struct GestureCanvasHostingView<Content: View>: View {
    let content: GestureCanvasHostedContent<Content>

    var body: some View {
        content.view
    }
}
