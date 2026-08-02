import SwiftUI

/// Confirmation shown when a city is tapped in search, before the trip's
/// destination is actually changed. Presented over the search sheet as a
/// bottom card with a dimming scrim.
struct CitySwitchConfirmCard: View {
    let cityName: String
    let currentCityName: String
    let isSwitching: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { if !isSwitching { onCancel() } }
                .accessibilityLabel("Dismiss")
                .accessibilityAddTraits(.isButton)

            card
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.lg)
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "airplane.departure")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(BrandColor.sand)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Travel to \(cityName)?")
                        .font(.headline17)
                        .foregroundStyle(AppColor.textPrimary)
                    Text("Your saved spots and cached suggestions for \(currentCityName) stay put.")
                        .font(.caption12)
                        .foregroundStyle(AppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: Spacing.sm) {
                Button("Cancel", action: onCancel)
                    .font(.subheadline15.weight(.medium))
                    .foregroundStyle(AppColor.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(AppColor.surfaceGrouped)
                    .clipShape(Capsule())
                    .disabled(isSwitching)

                Button(action: onConfirm) {
                    ZStack {
                        Text("Travel here")
                            .opacity(isSwitching ? 0 : 1)
                        if isSwitching {
                            ProgressView()
                                .tint(BrandColor.sandDeep)
                        }
                    }
                    .font(.subheadline15.weight(.semibold))
                    .foregroundStyle(BrandColor.sandDeep)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(BrandColor.sandTint)
                    .clipShape(Capsule())
                }
                .buttonStyle(.pressableScale)
                .disabled(isSwitching)
            }
            .padding(.top, Spacing.xs)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .liquidGlass(corner: 20, strength: .regular, interactive: true)
    }
}
