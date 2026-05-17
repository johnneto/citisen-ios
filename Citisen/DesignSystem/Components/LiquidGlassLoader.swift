import SwiftUI

/// Loading indicator shown while Gemini curation + Places resolution is running.
/// A pill of liquid glass, tinted with the active travel mode color, containing
/// a rotating gradient arc and a short label.
struct LiquidGlassLoader: View {
    let mode: TravelMode
    var label: String = "Generating suggestions…"
    var size: CGFloat = 28

    @State private var rotation: Double = 0

    var body: some View {
        HStack(spacing: Spacing.sm) {
            spinner
                .frame(width: size, height: size)
            Image(systemName: "sparkles")
                .foregroundStyle(mode.color)
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
        .shadow(color: mode.color.opacity(0.28), radius: 10, x: 0, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
        .onAppear {
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }

    private var spinner: some View {
        let strokeWidth = size * 0.12
        return ZStack {
            Circle()
                .stroke(mode.color.opacity(0.18), lineWidth: strokeWidth)
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [mode.color.opacity(0), mode.color]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(rotation))
        }
    }
}

/// Full-screen veil over the map while curation is running. Tints the screen
/// with a darkened version of the active travel-mode color and centers a
/// compact animated loader.
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
            LiquidGlassLoader(mode: mode, size: 36)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Generating suggestions")
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
