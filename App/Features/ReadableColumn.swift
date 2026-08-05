import SwiftUI

/// Caps content to a comfortable reading width and centers it. Without this,
/// chat bubbles and forms stretch across a 13" iPad and the app reads as a
/// blown-up phone app.
struct ReadableColumn: ViewModifier {
    var maxWidth: CGFloat = 720

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }
}

extension View {
    func readableColumn(maxWidth: CGFloat = 720) -> some View {
        modifier(ReadableColumn(maxWidth: maxWidth))
    }
}
