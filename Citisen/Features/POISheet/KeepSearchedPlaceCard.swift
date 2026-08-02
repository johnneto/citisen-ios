import SwiftUI

/// Offered on the POI sheet for a place the user reached through search rather
/// than AI curation. Keeping it files the place with the city's cached spots, so
/// it pins on the map and survives a relaunch; declining just hides the offer
/// for the rest of the session.
///
/// Deliberately an inline card rather than an alert: the choice is low-stakes
/// and reversible, and an alert would interrupt the details the user just asked
/// to see.
struct KeepSearchedPlaceCard: View {
    /// Name of the city the place would be filed under, or nil when it can't be
    /// resolved — the copy falls back to "your spots".
    let cityName: String?
    let onKeep: () -> Void
    let onDecline: () -> Void

    var body: some View {
        // Text on its own row rather than beside the buttons: at the compact
        // detent a side-by-side layout squeezes the copy down to an ellipsis.
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BrandColor.sand)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.footnote13.weight(.semibold))
                        .foregroundStyle(AppColor.textPrimary)
                    Text("You found this one, not the AI.")
                        .font(.caption12)
                        .foregroundStyle(AppColor.textSecondary)
                }
                .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }

            HStack(spacing: Spacing.md) {
                Spacer(minLength: 0)

                Button(action: onDecline) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColor.textTertiary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Not now")

                Button(action: onKeep) {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Keep")
                            .font(.footnote13.weight(.semibold))
                    }
                    .foregroundStyle(BrandColor.sand)
                    .frame(minHeight: 28)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppColor.surfaceGrouped)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }

    private var title: String {
        guard let cityName, !cityName.isEmpty else { return "Keep this in your spots?" }
        return "Keep this in your \(cityName) spots?"
    }
}
