import SwiftUI

/// Loading indicator shown while Gemini curation + Places resolution is running.
/// A liquid-glass pill tinted with the active travel-mode color, featuring an
/// animated sparkle (signalling AI generation), a soft pulsing aura, and a
/// shimmering label. Animations are driven by `TimelineView(.animation)` and
/// `.symbolEffect`, so they survive implicit parent animations on appear.
struct LiquidGlassLoader: View {
    let mode: TravelMode
    var label: String = "Generating suggestions"
    var size: CGFloat = 28

    var body: some View {
        HStack(spacing: Spacing.sm) {
            SparkleIndicator(color: mode.color, size: size)
            ShimmerLabel(text: label, isLarge: size > 40)
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
        .accessibilityLabel(label)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

/// Sparkle icon with a continuous twinkling symbol effect plus a soft pulsing
/// halo. The symbol effect uses the system's variable-color animation so it
/// keeps moving regardless of view-tree transactions.
private struct SparkleIndicator: View {
    let color: Color
    let size: CGFloat

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            // Slow breathing pulse: ~1.5s period.
            let pulse = (sin(t * 2.0 * .pi / 1.5) + 1) / 2
            let auraScale = 0.85 + pulse * 0.35
            let auraOpacity = 0.25 + pulse * 0.45
            let iconScale = 0.94 + pulse * 0.10

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [color.opacity(auraOpacity), color.opacity(0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.55
                        )
                    )
                    .scaleEffect(auraScale)

                Image(systemName: "sparkles")
                    .font(.system(size: size * 0.78, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(color)
                    .symbolEffect(
                        .variableColor.iterative.reversing,
                        options: .repeating
                    )
                    .scaleEffect(iconScale)
                    .shadow(color: color.opacity(0.55), radius: size * 0.18)
            }
        }
        .frame(width: size * 1.3, height: size * 1.3)
    }
}

/// Label whose foreground sweeps a soft highlight from left to right, hinting
/// that work is in progress. Time-driven so it cannot stall.
private struct ShimmerLabel: View {
    let text: String
    let isLarge: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            // Highlight position sweeps 0..1 over ~1.8s.
            let phase = (t.truncatingRemainder(dividingBy: 1.8)) / 1.8
            let center = CGFloat(phase) * 1.4 - 0.2 // overshoot for clean entry/exit

            Text(text)
                .font(isLarge ? .headline17.weight(.semibold) : .subheadline15.weight(.semibold))
                .foregroundStyle(
                    LinearGradient(
                        stops: [
                            .init(color: AppColor.textPrimary.opacity(0.55), location: max(0, center - 0.3)),
                            .init(color: AppColor.textPrimary, location: max(0, min(1, center))),
                            .init(color: AppColor.textPrimary.opacity(0.55), location: min(1, center + 0.3))
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .fixedSize(horizontal: true, vertical: false)
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
        LiquidGlassLoader(mode: .food, label: "Finding more spots…", size: 16)
    }
    .padding()
    .background(AppColor.surfacePrimary)
}

#Preview("Overlay") {
    MapLoadingOverlay(mode: .food)
}
