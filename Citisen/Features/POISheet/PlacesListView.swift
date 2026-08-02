import CoreLocation
import SwiftUI

struct PlacesListView: View {
    @Environment(AppRouter.self)
    private var router
    @Environment(PlacesService.self)
    private var places
    @Environment(CityService.self)
    private var cityService

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    ForEach(resolvedPlaces, id: \.id) { place in
                        Button {
                            router.placesListAnchorId = place.id
                            router.selectPlaceFromList(place.id)
                        } label: {
                            PlacesListRow(place: place, originCenter: cityService.activeCity.center.clLocation)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(AppColor.surfaceElevated)
                        .listRowSeparator(.visible)
                        .id(place.id)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(AppColor.surfacePrimary)
                .task {
                    if let anchor = router.placesListAnchorId {
                        proxy.scrollTo(anchor, anchor: .top)
                    }
                }
            }
            .navigationTitle("Places")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { router.dismissSheet() }
                        .tint(BrandColor.sand)
                }
            }
        }
    }

    private var resolvedPlaces: [Place] {
        router.poiPlaceIds.compactMap { places.place(id: $0) }
    }
}

private struct PlacesListRow: View {
    let place: Place
    let originCenter: CLLocationCoordinate2D

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            thumbnail
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    ModeChip(mode: place.mode, style: .tint)
                    closedBadge
                    Spacer(minLength: 0)
                }
                Text(place.name)
                    .font(.subheadline15.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(place.formattedDistance(from: originCenter))
                    if let rating = place.rating {
                        Text("·").foregroundStyle(AppColor.textTertiary)
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(AppColor.warning)
                            Text(String(format: "%.1f", rating))
                        }
                    }
                    Text("·").foregroundStyle(AppColor.textTertiary)
                    Text(place.category)
                        .lineLimit(1)
                }
                .font(.caption12)
                .foregroundStyle(AppColor.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    @ViewBuilder private var thumbnail: some View {
        if let first = place.photoNames?.first {
            PlacePhotoView(
                photoName: first,
                mode: place.mode,
                seed: place.id.uuidString,
                height: 72,
                cornerRadius: Radius.sm
            )
        } else {
            PlaceholderPhoto(
                seed: place.id.uuidString,
                mode: place.mode,
                height: 72,
                cornerRadius: Radius.sm
            )
        }
    }

    @ViewBuilder private var closedBadge: some View {
        switch place.businessStatus {
        case .closedTemporarily:
            ClosedStatusBadge(text: "Temporarily closed")
        case .closedPermanently:
            ClosedStatusBadge(text: "Permanently closed")
        default:
            EmptyView()
        }
    }
}
