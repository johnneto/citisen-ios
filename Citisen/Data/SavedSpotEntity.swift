import Foundation
import SwiftData

@Model
final class SavedSpotEntity {
    @Attribute(.unique)
    var placeId: UUID
    var googlePlaceId: String?
    var placeName: String
    var placeCategory: String
    var modeRaw: String
    var ratingRaw: String
    var note: String?
    var savedAt: Date
    var cityId: String = ""
    var cityName: String = ""
    var countryName: String = ""
    var emojiFlag: String = ""
    var collection: CollectionEntity?

    init(
        placeId: UUID,
        googlePlaceId: String? = nil,
        placeName: String,
        placeCategory: String,
        mode: TravelMode,
        rating: SavedSpotRating,
        note: String? = nil,
        cityId: String,
        cityName: String = "",
        countryName: String = "",
        emojiFlag: String = "",
        collection: CollectionEntity? = nil
    ) {
        self.placeId = placeId
        self.googlePlaceId = googlePlaceId
        self.placeName = placeName
        self.placeCategory = placeCategory
        self.modeRaw = mode.rawValue
        self.ratingRaw = rating.rawValue
        self.note = note
        self.savedAt = Date()
        self.cityId = cityId
        self.cityName = cityName
        self.countryName = countryName
        self.emojiFlag = emojiFlag
        self.collection = collection
    }

    var mode: TravelMode {
        TravelMode(rawValue: modeRaw) ?? .standard
    }

    var rating: SavedSpotRating {
        SavedSpotRating(rawValue: ratingRaw) ?? .wantToVisit
    }

    var resolvedCityName: String {
        cityName.isEmpty ? (City.all.first(where: { $0.id == cityId })?.name ?? cityId) : cityName
    }

    var resolvedCountryName: String {
        countryName.isEmpty ? (City.all.first(where: { $0.id == cityId })?.country ?? "") : countryName
    }

    var resolvedFlag: String {
        if !emojiFlag.isEmpty { return emojiFlag }
        return City.all.first(where: { $0.id == cityId })?.emojiFlag ?? ""
    }
}
