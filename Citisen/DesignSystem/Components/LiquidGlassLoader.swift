import SwiftUI

/// Loading indicator shown while Gemini curation + Places resolution is running.
/// A pill of liquid glass, tinted with the active travel mode color, containing
/// three orbiting blobs that pulse and a short label.
struct LiquidGlassLoader: View {
    let mode: TravelMode
    var label: String = "Curating spots…"

    @State private var phase: Double = 0
    @State private var breathe: Bool = false

    var body: some View {
        HStack(spacing: Spacing.sm) {
            orbit
                .frame(width: 28, height: 28)
            Text(label)
                .font(.subheadline15.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
                .accessibilityLabel(label)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 10)
        .liquidGlassPill(strength: .regular, interactive: false, tint: mode.color.opacity(0.45))
        .overlay(
            Capsule()
                .strokeBorder(mode.color.opacity(0.35), lineWidth: 0.8)
        )
        .shadow(color: mode.color.opacity(0.28), radius: breathe ? 18 : 10, x: 0, y: 6)
        .scaleEffect(breathe ? 1.02 : 1.0)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
        .onAppear {
            withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                phase = 1
            }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
    }

    private var orbit: some View {
        ZStack {
            Circle()
                .fill(mode.color.opacity(0.18))
            ForEach(0..<3, id: \.self) { index in
                blob(index: index)
            }
        }
    }

    @ViewBuilder
    private func blob(index: Int) -> some View {
        let baseAngle = (Double(index) / 3.0) * 2 * .pi
        let radius: CGFloat = 9
        let dx = CGFloat(cos(baseAngle + phase * 2 * .pi)) * radius
        let dy = CGFloat(sin(baseAngle + phase * 2 * .pi)) * radius
        Circle()
            .fill(mode.color)
            .frame(width: 7, height: 7)
            .offset(x: dx, y: dy)
            .opacity(0.65 + 0.35 * sin(phase * 2 * .pi + baseAngle))
    }
}

#Preview {
    VStack(spacing: 16) {
        LiquidGlassLoader(mode: .food)
        LiquidGlassLoader(mode: .nature)
        LiquidGlassLoader(mode: .nightlife)
    }
    .padding()
    .background(AppColor.surfacePrimary)
}
