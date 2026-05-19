import SwiftUI

struct LiquidGlassModifier: ViewModifier {
    let cornerRadius: CGFloat
    let strength: Strength
    let interactive: Bool
    let tint: Color?

    enum Strength {
        case thin, regular, thick

        var fallbackMaterial: Material {
            switch self {
            case .thin: return .thinMaterial
            case .regular: return .ultraThinMaterial
            case .thick: return .regularMaterial
            }
        }
    }

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(
                makeGlass(),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(strength.fallbackMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }

    @available(iOS 26.0, *)
    private func makeGlass() -> Glass {
        var base: Glass = strength == .thin ? .clear : .regular
        if let tint {
            base = base.tint(tint)
        }
        return interactive ? base.interactive() : base
    }
}

extension View {
    func liquidGlass(
        corner: CGFloat = Radius.xxl,
        strength: LiquidGlassModifier.Strength = .regular,
        interactive: Bool = false,
        tint: Color? = nil
    ) -> some View {
        modifier(
            LiquidGlassModifier(
                cornerRadius: corner,
                strength: strength,
                interactive: interactive,
                tint: tint
            )
        )
    }

    func liquidGlassPill(
        strength: LiquidGlassModifier.Strength = .thick,
        interactive: Bool = false,
        tint: Color? = nil
    ) -> some View {
        modifier(
            LiquidGlassModifier(
                cornerRadius: Radius.pill,
                strength: strength,
                interactive: interactive,
                tint: tint
            )
        )
    }
}
