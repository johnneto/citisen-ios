import CoreLocation
import Foundation
import SwiftData

@Model
class SavedPlace {
    #Index<SavedPlace>([\.countryCode], [\.city], [\.placeTypeRaw], [\.statusRaw])

    var id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var countryCode: String?
    var city: String?
    var statusRaw: String
    var placeTypeRaw: String
    var timestamp: Date

    var status: SavedPlaceStatus {
        get { SavedPlaceStatus(rawValue: statusRaw) ?? .wantToVisit }
        set { statusRaw = newValue.rawValue }
    }

    var placeType: PlaceType {
        get { PlaceType(rawValue: placeTypeRaw) ?? .other }
        set { placeTypeRaw = newValue.rawValue }
    }

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
        self.statusRaw = status.rawValue
        self.placeTypeRaw = placeType.rawValue
        self.timestamp = timestamp
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
