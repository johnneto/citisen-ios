import SwiftUI

struct LocationPermissionScreen: View {
    let onAllow: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: 24) {
                ZStack {
                    Circle().fill(BrandColor.sandTint)
                        .frame(width: 120, height: 120)
                        .shadow(color: BrandColor.sand.opacity(0.18), radius: 24, x: 0, y: 12)
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 58, weight: .semibold))
                        .foregroundStyle(BrandColor.sand)
                }

                VStack(spacing: 12) {
                    Text("Find what's around you")
                        .font(.title2)
                        .foregroundStyle(AppColor.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Citisen uses your location to surface nearby places that match your active travel modes. Nothing is ever shared without you.")
                        .font(.callout16)
                        .foregroundStyle(AppColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                        .lineSpacing(2)
                }
            }

            Spacer(minLength: 0)

            VStack(spacing: 8) {
                PrimaryButton(title: "Allow Location Access", iconSymbol: "location.fill", action: onAllow)
                GhostButton(title: "Not now", action: onSkip)
            }
        }
        .padding(.horizontal, Spacing.xxl)
        .padding(.top, 120)
        .padding(.bottom, 50)
    }
}

#Preview {
    LocationPermissionScreen(onAllow: {}, onSkip: {})
        .background(AppColor.surfacePrimary)
}
