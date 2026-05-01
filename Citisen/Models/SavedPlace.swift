import CoreLocation
import Foundation
import SwiftData

@Model
class SavedPlace {
    #Index<SavedPlace>([\.countryCode], [\.city], [\.placeType], [\.status])

    var id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var countryCode: String?
    var city: String?
    var status: SavedPlaceStatus
    var placeType: PlaceType
    var timestamp: Date

    init(
        id: UUID = UUID(),
        name: String,
        latitude: Double,
        longitude: Double,
        countryCode: String? = nil,
        city: String? = nil,
        status: SavedPlaceStatus = .wantToVisit,
        placeType: PlaceType = .other,
        timestamp: Date = .now
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.countryCode = countryCode
        self.city = city
        self.status = status
        self.placeType = placeType
        self.timestamp = timestamp
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
