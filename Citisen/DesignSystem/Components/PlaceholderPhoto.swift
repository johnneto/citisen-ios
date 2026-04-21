import SwiftUI

/// Deterministic gradient "photo" stand-in for places — avoids shipping bitmap
/// assets until Stage 5 pipes in Google Places photos.
struct PlaceholderPhoto: View {
    let seed: String
    let mode: TravelMode
    var height: CGFloat = 160
    var cornerRadius: CGFloat = Radius.md

    private var rotation: Angle {
        let hash = abs(seed.hashValue)
        return .degrees(Double(hash % 360))
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [mode.tintColor, mode.color.opacity(0.35), mode.color.opacity(0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: mode.iconSymbol)
                .font(.system(size: height * 0.32, weight: .semibold))
                .foregroundStyle(mode.color.opacity(0.45))
                .rotationEffect(rotation)
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(AppColor.dividerSoft, lineWidth: 0.5)
        )
    }
}
