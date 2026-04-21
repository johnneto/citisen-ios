import SwiftData
import SwiftUI

struct CollectionDetailView: View {
    let collectionId: UUID

    @Environment(\.modelContext)
    private var modelContext
    @Environment(AppRouter.self)
    private var router
    @Environment(\.dismiss)
    private var dismiss

    @Query private var collections: [CollectionEntity]

    @State private var isRenaming = false
    @State private var newName: String = ""

    init(collectionId: UUID) {
        self.collectionId = collectionId
        let id = collectionId
        _collections = Query(filter: #Predicate<CollectionEntity> { $0.id == id })
    }

    private var collection: CollectionEntity? { collections.first }

    var body: some View {
        ScrollView {
            if let collection {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    hero(collection)
                    meta(collection)

                    if collection.spots.isEmpty {
                        emptyState
                    } else {
                        spotList(collection)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, 40)
            } else {
                Text("Collection not found")
                    .font(.headline17)
                    .foregroundStyle(AppColor.textSecondary)
                    .padding(.top, 40)
            }
        }
        .background(AppColor.surfacePrimary.ignoresSafeArea())
        .navigationTitle(collection?.name ?? "Collection")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let collection {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            newName = collection.name
                            isRenaming = true
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            SavedSpotsService(context: modelContext).delete(collection)
                            dismiss()
                        } label: {
                            Label("Delete collection", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .tint(BrandColor.sand)
                }
            }
        }
        .alert("Rename collection", isPresented: $isRenaming) {
            TextField("Name", text: $newName)
            Button("Save") {
                guard let collection else { return }
                let trimmed = newName.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    SavedSpotsService(context: modelContext).rename(collection, to: trimmed)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func hero(_ collection: CollectionEntity) -> some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: collection.colorHexes.map { Color(hex: $0) },
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 160)

            HStack {
                Image(systemName: collection.iconSymbol)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.black.opacity(0.18))
                    .clipShape(Circle())
                Spacer()
            }
            .padding(Spacing.md)
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .padding(.top, Spacing.sm)
    }

    private func meta(_ collection: CollectionEntity) -> some View {
        HStack(spacing: 10) {
            Label("\(collection.spots.count) spots", systemImage: "mappin.and.ellipse")
            Text("·").foregroundStyle(AppColor.textTertiary)
            Label(collection.cityName, systemImage: "building.2")
        }
        .font(.footnote13)
        .foregroundStyle(AppColor.textSecondary)
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: "bookmark")
                .font(.system(size: 36))
                .foregroundStyle(AppColor.textTertiary)
                .padding(.top, Spacing.lg)
            Text("No spots yet")
                .font(.headline17)
                .foregroundStyle(AppColor.textPrimary)
            Text("Save a place from the map to add it here.")
                .font(.footnote13)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
    }

    private func spotList(_ collection: CollectionEntity) -> some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(collection.spots) { spot in
                Button {
                    router.openPOI(spot.placeId)
                } label: {
                    SavedSpotRow(spot: spot)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        SavedSpotsService(context: modelContext).removeSpot(spot)
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
                Divider().background(AppColor.dividerSoft).padding(.leading, 76)
            }
        }
    }
}
