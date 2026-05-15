import SwiftData
import SwiftUI

struct SavedGroupDetailView: View {
    let filter: SavedGroupFilter

    @Environment(AppRouter.self)
    private var router

    @Query(sort: \SavedSpotEntity.savedAt, order: .reverse)
    private var allSpots: [SavedSpotEntity]

    var body: some View {
        Group {
            if filteredSpots.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(filteredSpots) { spot in
                            Button {
                                router.dismissSheet()
                                router.openPOI(spot.placeId)
                            } label: {
                                SavedSpotRow(spot: spot, showLocation: showLocation)
                            }
                            .buttonStyle(.plain)
                            Divider()
                                .background(AppColor.dividerSoft)
                                .padding(.leading, 76)
                        }
                    }
                    .padding(.top, Spacing.sm)
                }
            }
        }
        .background(AppColor.surfacePrimary.ignoresSafeArea())
        .navigationTitle(filter.title)
        .navigationBarTitleDisplayMode(.large)
    }

    private var filteredSpots: [SavedSpotEntity] {
        allSpots.filter { spot in
            switch filter {
            case .country(let name, _):
                return spot.resolvedCountryName == name
            case .city(let cityId):
                return spot.cityId == cityId
            case .mode(let mode):
                return spot.mode == mode
            }
        }
    }

    private var showLocation: Bool {
        switch filter {
        case .country: return true
        case .city:    return false
        case .mode:    return true
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.sm) {
            Spacer()
            Image(systemName: emptyIcon)
                .font(.system(size: 36))
                .foregroundStyle(AppColor.textTertiary)
            Text("No spots here")
                .font(.headline17)
                .foregroundStyle(AppColor.textPrimary)
            Text("Saved spots for \(filter.title) will appear here.")
                .font(.footnote13)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.lg)
    }

    private var emptyIcon: String {
        switch filter {
        case .country, .city: return "mappin.and.ellipse"
        case .mode(let mode): return mode.iconSymbol
        }
    }
}
