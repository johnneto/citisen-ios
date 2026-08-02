import Foundation

enum SubFilter: String, CaseIterable, Identifiable, Codable, Hashable {
    case openNow
    case topRated
    case fourPlus
    case lowBudget
    case newInCity

    var id: String { rawValue }

    var label: String {
        switch self {
        case .openNow: return "Open now"
        case .topRated: return "Top rated"
        case .fourPlus: return "4+ stars"
        case .lowBudget: return "Low budget"
        case .newInCity: return "New in the city"
        }
    }

    var iconSymbol: String? {
        switch self {
        case .openNow: return "clock"
        case .topRated: return "star"
        case .fourPlus: return "star"
        case .lowBudget: return nil
        case .newInCity: return "sparkles"
        }
    }

    func matches(_ place: Place) -> Bool {
        switch self {
        case .openNow: return place.isOpenNow
        case .topRated: return (place.rating ?? 0) >= 4.5
        case .fourPlus: return (place.rating ?? 0) >= 4
        case .lowBudget: return place.priceLevel.map { $0 <= 1 } ?? false
        case .newInCity: return place.tags.contains("New")
        }
    }
}
