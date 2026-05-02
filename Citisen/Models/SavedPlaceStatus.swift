import Foundation

enum SavedPlaceStatus: String, Codable, CaseIterable, Identifiable {
    case wantToVisit = "Want to Visit"
    case good = "Good"
    case dontGo = "Don't Go"

    var id: String { rawValue }
}
