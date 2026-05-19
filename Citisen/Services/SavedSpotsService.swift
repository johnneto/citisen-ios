import Foundation
import OSLog
import SwiftData

@MainActor
final class SavedSpotsService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    private func persist(_ op: StaticString) {
        do {
            try context.save()
        } catch {
            AppLog.data.error("SavedSpotsService.\(op, privacy: .public) save failed: \(error.localizedDescription, privacy: .public)")
        }
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

    func setRating(
        _ rating: SavedSpotRating,
        for place: Place,
        cityName: String? = nil,
        countryName: String? = nil,
        emojiFlag: String? = nil
    ) {
        let fallback = City.all.first(where: { $0.id == place.cityId })
        let resolvedCityName: String = {
            if let cityName, !cityName.isEmpty { return cityName }
            return fallback?.name ?? ""
        }()
        let resolvedCountryName: String = {
            if let countryName, !countryName.isEmpty { return countryName }
            return fallback?.country ?? ""
        }()
        let resolvedFlag: String = {
            if let emojiFlag, !emojiFlag.isEmpty { return emojiFlag }
            return fallback?.emojiFlag ?? ""
        }()

        if let existing = spot(for: place.id) {
            if existing.googlePlaceId == nil, let gpid = place.googlePlaceId {
                existing.googlePlaceId = gpid
            }
            if existing.cityName.isEmpty, !resolvedCityName.isEmpty {
                existing.cityName = resolvedCityName
            }
            if existing.countryName.isEmpty, !resolvedCountryName.isEmpty {
                existing.countryName = resolvedCountryName
            }
            if existing.emojiFlag.isEmpty, !resolvedFlag.isEmpty {
                existing.emojiFlag = resolvedFlag
            }
            if existing.rating == rating {
                context.delete(existing)
            } else {
                existing.ratingRaw = rating.rawValue
            }
        } else {
            let entity = SavedSpotEntity(
                placeId: place.id,
                googlePlaceId: place.googlePlaceId,
                placeName: place.name,
                placeCategory: place.category,
                mode: place.mode,
                rating: rating,
                cityId: place.cityId,
                cityName: resolvedCityName,
                countryName: resolvedCountryName,
                emojiFlag: resolvedFlag
            )
            context.insert(entity)
        }
        persist("setRating")
    }

    func googlePlaceId(for placeId: UUID) -> String? {
        spot(for: placeId)?.googlePlaceId
    }

    func unsave(placeId: UUID) {
        guard let existing = spot(for: placeId) else { return }
        context.delete(existing)
        persist("unsave")
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
        persist("collection")
        return entity
    }

    func delete(_ collection: CollectionEntity) {
        context.delete(collection)
        persist("collection")
    }

    func rename(_ collection: CollectionEntity, to name: String) {
        collection.name = name
        persist("collection")
    }

    func addSpot(_ spot: SavedSpotEntity, to collection: CollectionEntity) {
        spot.collection = collection
        persist("collection")
    }

    func removeSpot(_ spot: SavedSpotEntity) {
        context.delete(spot)
        persist("collection")
    }
}
