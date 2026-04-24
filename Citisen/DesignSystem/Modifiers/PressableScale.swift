import SwiftUI

struct PressableScaleStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    var haptic: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                guard haptic, pressed else { return }
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
            }
    }
}

extension ButtonStyle where Self == PressableScaleStyle {
    static var pressableScale: PressableScaleStyle { PressableScaleStyle() }
}
