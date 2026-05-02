import SwiftUI

struct CardShadowModifier: ViewModifier {
    var elevated: Bool = false

    func body(content: Content) -> some View {
        content
            .shadow(
                color: .black.opacity(elevated ? 0.16 : 0.08),
                radius: elevated ? 18 : 10,
                x: 0,
                y: elevated ? 10 : 4
            )
    }
}

extension View {
    func cardShadow(elevated: Bool = false) -> some View {
        modifier(CardShadowModifier(elevated: elevated))
    }
}
