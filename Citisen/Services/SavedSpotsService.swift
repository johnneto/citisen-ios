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
                deleteMirroredPlace(for: place.id)
            } else {
                existing.ratingRaw = rating.rawValue
                updateMirroredPlace(for: place.id, rating: rating)
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
            insertMirroredPlace(for: place, rating: rating)
        }
        try? context.save()
    }

    func unsave(placeId: UUID) {
        guard let existing = spot(for: placeId) else { return }
        context.delete(existing)
        deleteMirroredPlace(for: placeId)
        try? context.save()
    }

    func allSpots() -> [SavedSpotEntity] {
        let descriptor = FetchDescriptor<SavedSpotEntity>(
            sortBy: [SortDescriptor(\.savedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - SavedPlace mirror

    private func mirroredPlace(for placeId: UUID) -> SavedPlace? {
        var descriptor = FetchDescriptor<SavedPlace>(
            predicate: #Predicate { $0.id == placeId }
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    private func insertMirroredPlace(for place: Place, rating: SavedSpotRating) {
        let saved = SavedPlace(
            id: place.id,
            name: place.name,
            latitude: place.coordinate.latitude,
            longitude: place.coordinate.longitude,
            status: savedPlaceStatus(from: rating),
            placeType: placeType(from: place.category)
        )
        context.insert(saved)
    }

    private func updateMirroredPlace(for placeId: UUID, rating: SavedSpotRating) {
        guard let existing = mirroredPlace(for: placeId) else { return }
        existing.status = savedPlaceStatus(from: rating)
    }

    private func deleteMirroredPlace(for placeId: UUID) {
        guard let existing = mirroredPlace(for: placeId) else { return }
        context.delete(existing)
    }

    private func savedPlaceStatus(from rating: SavedSpotRating) -> SavedPlaceStatus {
        switch rating {
        case .wantToVisit: return .wantToVisit
        case .betterThanExpected, .good: return .good
        case .skippable, .dontGo: return .dontGo
        }
    }

    private func placeType(from category: String) -> PlaceType {
        let lower = category.lowercased()
        if lower.contains("cafe") || lower.contains("coffee") { return .cafe }
        if lower.contains("restaurant") || lower.contains("food") { return .restaurant }
        if lower.contains("museum") { return .museum }
        if lower.contains("hotel") || lower.contains("accommodation") { return .hotel }
        if lower.contains("park") || lower.contains("garden") { return .park }
        if lower.contains("landmark") || lower.contains("attraction") { return .landmark }
        if lower.contains("shopping") || lower.contains("store") || lower.contains("market") { return .shopping }
        return .other
    }
}
