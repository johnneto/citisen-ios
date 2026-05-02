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

    init(
        placeId: UUID,
        placeName: String,
        placeCategory: String,
        mode: TravelMode,
        rating: SavedSpotRating,
        note: String? = nil,
        cityId: String
    ) {
        self.placeId = placeId
        self.placeName = placeName
        self.placeCategory = placeCategory
        self.modeRaw = mode.rawValue
        self.ratingRaw = rating.rawValue
        self.note = note
        self.savedAt = Date()
        self.cityId = cityId
    }

    var mode: TravelMode {
        TravelMode(rawValue: modeRaw) ?? .standard
    }

    var rating: SavedSpotRating {
        SavedSpotRating(rawValue: ratingRaw) ?? .wantToVisit
    }
}
