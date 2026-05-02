import Foundation

enum PlaceType: String, Codable, CaseIterable, Identifiable {
    case restaurant = "Restaurant"
    case museum = "Museum"
    case hotel = "Hotel"
    case park = "Park"
    case landmark = "Landmark"
    case cafe = "Cafe"
    case shopping = "Shopping"
    case other = "Other"

    var id: String { rawValue }
}
