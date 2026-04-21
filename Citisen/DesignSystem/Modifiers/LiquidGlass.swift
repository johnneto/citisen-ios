import SwiftUI

struct LiquidGlassModifier: ViewModifier {
    let cornerRadius: CGFloat
    let strength: Strength

    enum Strength {
        case thin, regular, thick

        var material: Material {
            switch self {
            case .thin: return .thinMaterial
            case .regular: return .ultraThinMaterial
            case .thick: return .regularMaterial
            }
        }
    }

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(strength.material)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

extension View {
    func liquidGlass(
        corner: CGFloat = Radius.xxl,
        strength: LiquidGlassModifier.Strength = .regular
    ) -> some View {
        modifier(LiquidGlassModifier(cornerRadius: corner, strength: strength))
    }

    func liquidGlassPill(strength: LiquidGlassModifier.Strength = .thick) -> some View {
        modifier(LiquidGlassModifier(cornerRadius: Radius.pill, strength: strength))
    }
}
