import SwiftUI

struct WelcomeScreen: View {
    let onGetStarted: () -> Void
    let onSignIn: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: 28) {
                CompassLogo(size: 120)
                    .shadow(color: BrandColor.sand.opacity(0.25), radius: 24, x: 0, y: 8)

                VStack(spacing: 10) {
                    Text("Citisen")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(AppColor.textPrimary)
                        .kerning(-1.2)

                    Text("Explore the city.\nLive like a local.")
                        .font(.body17)
                        .foregroundStyle(AppColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }
            }

            Spacer(minLength: 0)

            VStack(spacing: 12) {
                PrimaryButton(title: "Get Started", action: onGetStarted)
                GhostButton(title: "I already have an account", action: onSignIn)
            }
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.top, 120)
        .padding(.bottom, 50)
    }
}

#Preview {
    WelcomeScreen(onGetStarted: {}, onSignIn: {})
        .background(AppColor.surfacePrimary)
}
