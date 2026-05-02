import SwiftUI

struct SavedPlaceRowView: View {
    let place: SavedPlace

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .font(.subheadline15.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    if let city = place.city {
                        Text(city)
                    }
                    if let code = place.countryCode {
                        Text(code.flagEmoji())
                        Text(Locale.current.localizedString(forRegionCode: code) ?? code)
                    }
                }
                .font(.caption12)
                .foregroundStyle(AppColor.textSecondary)
                .lineLimit(1)
            }

            Spacer()

            Text(place.status.rawValue)
                .font(.caption12)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor(for: place.status))
                .foregroundStyle(.white)
                .clipShape(.rect(cornerRadius: Radius.sm))
        }
        .padding(.vertical, 4)
    }

    private func statusColor(for status: SavedPlaceStatus) -> Color {
        switch status {
        case .wantToVisit: BrandColor.sand
        case .good: AppColor.success
        case .dontGo: AppColor.danger
        }
    }
}
