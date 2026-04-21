import SwiftUI

struct PrimaryButton: View {
    let title: String
    var iconSymbol: String?
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                if let iconSymbol {
                    Image(systemName: iconSymbol)
                        .font(.headline)
                }
                Text(title)
                    .font(.headline17)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(.white)
            .background(BrandColor.sand.opacity(isEnabled ? 1 : 0.5))
            .clipShape(Capsule())
            .shadow(color: BrandColor.sand.opacity(isEnabled ? 0.35 : 0), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.pressableScale)
        .disabled(!isEnabled)
    }
}

struct GhostButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.callout16)
                .foregroundStyle(AppColor.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.pressableScale)
    }
}

struct SecondaryButton: View {
    let title: String
    var iconSymbol: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                if let iconSymbol {
                    Image(systemName: iconSymbol)
                }
                Text(title)
                    .font(.headline17)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(AppColor.textPrimary)
            .background(AppColor.surfaceElevated)
            .overlay(
                Capsule().strokeBorder(AppColor.divider, lineWidth: 0.5)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.pressableScale)
    }
}
