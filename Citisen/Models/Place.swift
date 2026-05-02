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

struct Place: Identifiable, Hashable, Codable {
    let id: UUID
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
