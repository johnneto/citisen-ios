import SwiftUI

/// Loading indicator shown while Gemini curation + Places resolution is running.
/// A pill of liquid glass, tinted with the active travel mode color, containing
/// three orbiting blobs that pulse and a short label.
struct LiquidGlassLoader: View {
    let mode: TravelMode
    var label: String = "Curating spots…"
    var size: CGFloat = 28

    @State private var phase: Double = 0
    @State private var breathe: Bool = false

    var body: some View {
        HStack(spacing: Spacing.sm) {
            orbit
                .frame(width: size, height: size)
            Text(label)
                .font(size > 40 ? .headline17.weight(.semibold) : .subheadline15.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
                .accessibilityLabel(label)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, size > 40 ? Spacing.md : 10)
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
        let radius: CGFloat = size * 0.32
        let blobSize: CGFloat = size * 0.25
        let dx = CGFloat(cos(baseAngle + phase * 2 * .pi)) * radius
        let dy = CGFloat(sin(baseAngle + phase * 2 * .pi)) * radius
        Circle()
            .fill(mode.color)
            .frame(width: blobSize, height: blobSize)
            .offset(x: dx, y: dy)
            .opacity(0.65 + 0.35 * sin(phase * 2 * .pi + baseAngle))
    }
}

/// Full-screen veil over the map while curation is running. Tints the screen
/// with a darkened version of the active travel-mode color and centers a
/// large animated loader.
struct MapLoadingOverlay: View {
    let mode: TravelMode

    var body: some View {
        ZStack {
            Rectangle()
                .fill(mode.color)
                .opacity(0.35)
            Rectangle()
                .fill(Color.black)
                .opacity(0.45)
            LiquidGlassLoader(mode: mode, size: 72)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Curating spots")
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

#Preview("Overlay") {
    MapLoadingOverlay(mode: .food)
}
