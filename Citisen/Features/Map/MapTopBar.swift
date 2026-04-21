import SwiftUI

struct MapTopBar: View {
    let cityName: String
    let onTapHamburger: () -> Void
    let onTapCity: () -> Void
    let onTapSearch: () -> Void
    let onTapAvatar: () -> Void

    @Environment(UserPreferencesService.self) private var prefs

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Button(action: onTapHamburger) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppColor.textPrimary)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("Open menu")

            Button(action: onTapCity) {
                HStack(spacing: 4) {
                    Text(cityName)
                        .font(.headline17)
                        .foregroundStyle(AppColor.textPrimary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
            .buttonStyle(.pressableScale)
            .accessibilityLabel("Change city")

            Spacer()

            Button(action: onTapSearch) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppColor.textPrimary)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("Search")

            Button(action: onTapAvatar) {
                Avatar(initials: prefs.user.initials, size: 34)
            }
            .accessibilityLabel("Open profile")
        }
        .padding(.horizontal, 12)
        .frame(height: 56)
        .liquidGlass(corner: 28, strength: .regular)
    }
}
