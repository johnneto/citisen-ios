import Foundation
import SwiftData

@Model
final class SavedSpotEntity {
    @Attribute(.unique)
    var placeId: UUID
    var placeName: String
    var placeCategory: String
    var modeRaw: String
    var ratingRaw: String
    var note: String?
    var savedAt: Date
    var cityId: String
    var collection: CollectionEntity?

    init(
        placeId: UUID,
        placeName: String,
        placeCategory: String,
        mode: TravelMode,
        rating: SavedSpotRating,
        note: String? = nil,
        cityId: String,
        collection: CollectionEntity? = nil
    ) {
        self.placeId = placeId
        self.placeName = placeName
        self.placeCategory = placeCategory
        self.modeRaw = mode.rawValue
        self.ratingRaw = rating.rawValue
        self.note = note
        self.savedAt = Date()
        self.cityId = cityId
        self.collection = collection
    }

    var mode: TravelMode {
        TravelMode(rawValue: modeRaw) ?? .standard
    }

    var rating: SavedSpotRating {
        SavedSpotRating(rawValue: ratingRaw) ?? .wantToVisit
    }
}
