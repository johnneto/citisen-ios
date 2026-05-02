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
}
