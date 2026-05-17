import SwiftUI

/// Brief branded splash shown over the main UI on cold start. Flows naturally out of
/// the system launch screen (`BrandSand` background) and fades into `RootView`.
struct SplashView: View {
    @State private var appeared = false

    var body: some View {
        ZStack {
            BrandColor.sand
                .ignoresSafeArea()

            VStack(spacing: Spacing.md) {
                CompassLogo(size: 140)
                    .scaleEffect(appeared ? 1.0 : 0.85)
                    .opacity(appeared ? 1.0 : 0.0)

                Text("Citisen")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(Color(hex: "0D0D0D"))
                    .kerning(1.5)
                    .opacity(appeared ? 1.0 : 0.0)
                    .offset(y: appeared ? 0 : 8)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) {
                appeared = true
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Citisen")
    }
}

#Preview {
    SplashView()
}
