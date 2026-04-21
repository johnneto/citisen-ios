import SwiftUI

enum TravelMode: String, CaseIterable, Codable, Identifiable, Hashable {
    case standard
    case food
    case nature
    case turbo
    case history
    case sports
    case nightlife
    case cafes
    case art

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .food: return "Food"
        case .nature: return "Nature"
        case .turbo: return "Turbo"
        case .history: return "History"
        case .sports: return "Sports"
        case .nightlife: return "Nightlife"
        case .cafes: return "Cafés"
        case .art: return "Art"
        }
    }

    var tagline: String {
        switch self {
        case .standard: return "The best of the city — AI curated mix."
        case .food: return "Authentic local kitchens, not tourist traps."
        case .nature: return "Parks, coasts, quiet green escapes."
        case .turbo: return "Quick hits when you only have an afternoon."
        case .history: return "Layers of the past worth a detour."
        case .sports: return "Pitches, trails, adrenaline venues."
        case .nightlife: return "Bars, clubs, late-night corners locals love."
        case .cafes: return "Coffee rooms for long slow mornings."
        case .art: return "Galleries, murals, studios off the main drag."
        }
    }

    var iconSymbol: String {
        switch self {
        case .standard: return "safari.fill"
        case .food: return "fork.knife"
        case .nature: return "leaf.fill"
        case .turbo: return "bolt.fill"
        case .history: return "building.columns.fill"
        case .sports: return "figure.run"
        case .nightlife: return "moon.stars.fill"
        case .cafes: return "cup.and.saucer.fill"
        case .art: return "paintpalette.fill"
        }
    }

    var palette: ModePalette.Pair {
        switch self {
        case .standard: return ModePalette.standard
        case .food: return ModePalette.food
        case .nature: return ModePalette.nature
        case .turbo: return ModePalette.turbo
        case .history: return ModePalette.history
        case .sports: return ModePalette.sports
        case .nightlife: return ModePalette.nightlife
        case .cafes: return ModePalette.cafes
        case .art: return ModePalette.art
        }
    }

    var color: Color { palette.color }
    var tintColor: Color { palette.tint }

    static var customizable: [TravelMode] {
        allCases.filter { $0 != .standard }
    }
}
