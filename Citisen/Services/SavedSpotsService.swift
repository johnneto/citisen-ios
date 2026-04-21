import Foundation
import SwiftData

@MainActor
final class SavedSpotsService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Spots

    func savedRating(for placeId: UUID) -> SavedSpotRating? {
        spot(for: placeId)?.rating
    }

    func spot(for placeId: UUID) -> SavedSpotEntity? {
        var descriptor = FetchDescriptor<SavedSpotEntity>(
            predicate: #Predicate { $0.placeId == placeId }
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    func setRating(_ rating: SavedSpotRating, for place: Place) {
        if let existing = spot(for: place.id) {
            if existing.rating == rating {
                context.delete(existing)
            } else {
                existing.ratingRaw = rating.rawValue
            }
        } else {
            let entity = SavedSpotEntity(
                placeId: place.id,
                placeName: place.name,
                placeCategory: place.category,
                mode: place.mode,
                rating: rating,
                cityId: place.cityId
            )
            context.insert(entity)
        }
        try? context.save()
    }

    func unsave(placeId: UUID) {
        guard let existing = spot(for: placeId) else { return }
        context.delete(existing)
        try? context.save()
    }

    func allSpots() -> [SavedSpotEntity] {
        let descriptor = FetchDescriptor<SavedSpotEntity>(
            sortBy: [SortDescriptor(\.savedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Collections

    func allCollections() -> [CollectionEntity] {
        let descriptor = FetchDescriptor<CollectionEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    @discardableResult
    func createCollection(
        name: String,
        city: City,
        colorHexes: [String] = ["C8975A", "D4695E", "4A8C6F"],
        iconSymbol: String = "bookmark.fill"
    ) -> CollectionEntity {
        let entity = CollectionEntity(
            name: name,
            cityId: city.id,
            cityName: city.name,
            countryName: city.country,
            colorHexes: colorHexes,
            iconSymbol: iconSymbol
        )
        context.insert(entity)
        try? context.save()
        return entity
    }

    func delete(_ collection: CollectionEntity) {
        context.delete(collection)
        try? context.save()
    }

    func rename(_ collection: CollectionEntity, to name: String) {
        collection.name = name
        try? context.save()
    }

    func addSpot(_ spot: SavedSpotEntity, to collection: CollectionEntity) {
        spot.collection = collection
        try? context.save()
    }

    func removeSpot(_ spot: SavedSpotEntity) {
        context.delete(spot)
        try? context.save()
    }
}
