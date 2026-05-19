import CoreLocation
import Foundation

struct Coordinate: Codable, Hashable {
    let latitude: Double
    let longitude: Double

    var clLocation: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct OpeningHours: Codable, Hashable {
    var monday: String?
    var tuesday: String?
    var wednesday: String?
    var thursday: String?
    var friday: String?
    var saturday: String?
    var sunday: String?

    var hasAny: Bool {
        monday != nil || tuesday != nil || wednesday != nil || thursday != nil
            || friday != nil || saturday != nil || sunday != nil
    }

    var weekList: [(day: String, hours: String)] {
        [
            ("Mon", monday ?? "Closed"),
            ("Tue", tuesday ?? "Closed"),
            ("Wed", wednesday ?? "Closed"),
            ("Thu", thursday ?? "Closed"),
            ("Fri", friday ?? "Closed"),
            ("Sat", saturday ?? "Closed"),
            ("Sun", sunday ?? "Closed")
        ]
    }
}

struct Review: Codable, Hashable, Identifiable {
    let id: UUID
    let authorName: String
    let rating: Int
    let daysAgo: Int
    let text: String
}

enum BusinessStatus: String, Codable, Hashable {
    case operational
    case closedTemporarily
    case closedPermanently
    case unknown
}

struct Place: Identifiable, Hashable, Codable {
    let id: UUID
    let googlePlaceId: String?
    let cityId: String
    let name: String
    let category: String
    let mode: TravelMode
    let coordinate: Coordinate
    let rating: Double
    let reviewCount: Int
    let priceLevel: Int
    let description: String
    let tags: [String]
    let openingHours: OpeningHours
    let isOpenNow: Bool
    let closesAt: String?
    let reviews: [Review]
    let address: String
    let website: URL?
    let phone: String?
    let photoNames: [String]?
    let businessStatus: BusinessStatus

    init(
        id: UUID,
        googlePlaceId: String? = nil,
        cityId: String,
        name: String,
        category: String,
        mode: TravelMode,
        coordinate: Coordinate,
        rating: Double,
        reviewCount: Int,
        priceLevel: Int,
        description: String,
        tags: [String],
        openingHours: OpeningHours,
        isOpenNow: Bool,
        closesAt: String?,
        reviews: [Review],
        address: String,
        website: URL?,
        phone: String?,
        photoNames: [String]? = nil,
        businessStatus: BusinessStatus = .unknown
    ) {
        self.id = id
        self.googlePlaceId = googlePlaceId
        self.cityId = cityId
        self.name = name
        self.category = category
        self.mode = mode
        self.coordinate = coordinate
        self.rating = rating
        self.reviewCount = reviewCount
        self.priceLevel = priceLevel
        self.description = description
        self.tags = tags
        self.openingHours = openingHours
        self.isOpenNow = isOpenNow
        self.closesAt = closesAt
        self.reviews = reviews
        self.address = address
        self.website = website
        self.phone = phone
        self.photoNames = photoNames
        self.businessStatus = businessStatus
    }

    static func id(forGooglePlaceId googlePlaceId: String) -> UUID {
        UUID.v5(namespace: .citisenPlacesNamespace, name: googlePlaceId)
    }

    var budgetLabel: String {
        switch priceLevel {
        case 0: return "Free"
        case 1: return "$"
        case 2: return "$$"
        case 3: return "$$$"
        default: return "$$$$"
        }
    }

    func distance(from origin: CLLocationCoordinate2D) -> CLLocationDistance {
        let pointA = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let pointB = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        return pointA.distance(from: pointB)
    }

    func formattedDistance(from origin: CLLocationCoordinate2D, metric: Bool = true) -> String {
        let meters = distance(from: origin)
        if metric {
            if meters < 1000 {
                return "\(Int(meters)) m"
            }
            return String(format: "%.1f km", meters / 1000)
        }
        let miles = meters / 1609.34
        if miles < 0.1 {
            return String(format: "%.0f ft", meters * 3.281)
        }
        return String(format: "%.1f mi", miles)
    }
}
