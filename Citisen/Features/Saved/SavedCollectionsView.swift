import SwiftData
import SwiftUI

struct SavedCollectionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Environment(CityService.self) private var cityService

    @Query(sort: \CollectionEntity.createdAt, order: .reverse)
    private var collections: [CollectionEntity]

    @Query(sort: \SavedSpotEntity.savedAt, order: .reverse)
    private var allSpots: [SavedSpotEntity]

    @State private var selectedTab: Tab = .collections

    enum Tab: Hashable { case collections, spots }

    var body: some View {
        VStack(spacing: 0) {
            segmented
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.sm)

            if selectedTab == .collections {
                collectionsGrid
            } else {
                spotsList
            }
        }
        .background(AppColor.surfacePrimary.ignoresSafeArea())
        .navigationTitle("Saved")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    router.present(.newCollection)
                } label: {
                    Image(systemName: "plus")
                }
                .tint(BrandColor.sand)
                .accessibilityLabel("New collection")
            }
        }
    }

    private var segmented: some View {
        HStack(spacing: 0) {
            segmentButton("Collections", tab: .collections)
            segmentButton("All spots", tab: .spots)
        }
        .padding(4)
        .background(AppColor.surfaceGrouped)
        .clipShape(Capsule())
    }

    private func segmentButton(_ label: String, tab: Tab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
        } label: {
            Text(label)
                .font(.subheadline15.weight(.semibold))
                .foregroundStyle(selectedTab == tab ? AppColor.textPrimary : AppColor.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(selectedTab == tab ? AppColor.surfaceElevated : .clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var collectionsGrid: some View {
        if collections.isEmpty {
            emptyCollections
        } else {
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                    spacing: 12
                ) {
                    ForEach(collections) { collection in
                        Button {
                            router.push(.collectionDetail(collection.id))
                        } label: {
                            CollectionCardView(collection: collection)
                        }
                        .buttonStyle(.pressableScale)
                        .contextMenu {
                            Button(role: .destructive) {
                                SavedSpotsService(context: modelContext).delete(collection)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(Spacing.lg)
            }
        }
    }

    private var emptyCollections: some View {
        VStack(spacing: Spacing.sm) {
            Spacer()
            Image(systemName: "bookmark")
                .font(.system(size: 36))
                .foregroundStyle(AppColor.textTertiary)
            Text("No collections yet")
                .font(.headline17)
                .foregroundStyle(AppColor.textPrimary)
            Text("Group your saved spots into a trip or theme.")
                .font(.footnote13)
                .foregroundStyle(AppColor.textSecondary)
            Button {
                router.present(.newCollection)
            } label: {
                Label("New collection", systemImage: "plus")
                    .font(.subheadline15.weight(.semibold))
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(BrandColor.sand)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .padding(.top, Spacing.sm)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var spotsList: some View {
        if allSpots.isEmpty {
            VStack(spacing: Spacing.sm) {
                Spacer()
                Image(systemName: "star")
                    .font(.system(size: 36))
                    .foregroundStyle(AppColor.textTertiary)
                Text("No saved spots")
                    .font(.headline17)
                Text("Tap Save on any place to rate it.")
                    .font(.footnote13)
                    .foregroundStyle(AppColor.textSecondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(allSpots) { spot in
                        Button {
                            router.dismissSheet()
                            router.openPOI(spot.placeId)
                        } label: {
                            SavedSpotRow(spot: spot)
                        }
                        .buttonStyle(.plain)
                        Divider().background(AppColor.dividerSoft).padding(.leading, 76)
                    }
                }
                .padding(.top, Spacing.sm)
            }
        }
    }
}

struct CollectionCardView: View {
    let collection: CollectionEntity

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    colors: collection.colorHexes.map { Color(hex: $0) },
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .aspectRatio(1.0, contentMode: .fill)

                Image(systemName: collection.iconSymbol)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(Spacing.md)
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(collection.name)
                    .font(.headline17)
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(1)
                Text("\(collection.spots.count) spots · \(collection.cityName)")
                    .font(.caption12)
                    .foregroundStyle(AppColor.textSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
        }
    }
}

struct SavedSpotRow: View {
    let spot: SavedSpotEntity

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(spot.mode.tintColor)
                Image(systemName: spot.mode.iconSymbol)
                    .foregroundStyle(spot.mode.color)
                    .font(.system(size: 20, weight: .semibold))
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 2) {
                Text(spot.placeName)
                    .font(.subheadline15.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(spot.placeCategory)
                    Text("·").foregroundStyle(AppColor.textTertiary)
                    Image(systemName: spot.rating.iconSymbol)
                        .font(.system(size: 10))
                        .foregroundStyle(spot.rating.color)
                    Text(spot.rating.label)
                        .foregroundStyle(spot.rating.color)
                }
                .font(.caption12)
                .foregroundStyle(AppColor.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption12)
                .foregroundStyle(AppColor.textTertiary)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
