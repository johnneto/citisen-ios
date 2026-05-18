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
        case .turbo: return "Quick hits when you don't have much time."
        case .history: return "Details of the past worth a detour."
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

    /// Min/max number of curated spots Gemini should return for this mode.
    /// Falls back to AppConfig defaults; tweaked per mode where the experience benefits
    /// from a tighter or looser batch (e.g. turbo = quick hits, history = denser exploration).
    var suggestionCountRange: (min: Int, max: Int) {
        switch self {
        case .turbo:
            return (15, 25)
        case .nature, .sports:
            return (10, 20)
        case .history, .art:
            return (20, 30)
        case .standard, .food, .cafes, .nightlife:
            return (AppConfig.Spots.minSpotsPerRequest, AppConfig.Spots.maxSpotsPerRequest)
        }
    }

    var promptInstructions: String {
        switch self {
        case .standard:
            return """
            Curate a balanced sampler of the area, priotizing interesting places for someone visiting the city. \
            Skip places that are famous for being a tourist trap and hotels.
            """
        case .food:
            return """
            Focus on independently owned restaurants beloved by residents. \
            Mix price tiers, include at least 5 regional specialties, \
            casual daytime spots, dinner spots. \
            Always prioritize places that offer regional food or \
            interesting dishes that are special to the city or country. \
            Exclude hotels.
            """
        case .nature:
            return """
            Parks, famous trails, urban gardens, riverside walks, viewpoints, \
            quiet green pockets. Prioritize sites that are special to the city or country.
            """
        case .turbo:
            return """
            Pick only spots that are a must-see and essential for tourists when quickly visiting the region, \
            like iconic buildings, statues, museums, famous landmarks, parks and any place that is most relevant \
            considering a short trip. \
            Skip hotels unless important for visiting, generic suggestions or \
            places that are not essential to see for visitors.
            """
        case .history:
            return """
            Pick spots linked to hitorical facts like conflicts, famous figures, \
            neighbourhoods with preserved character, architecture highlights, museums and plaques. \
            Include at least 3 less known but curious spots using Atlas Obscura.
            """
        case .sports:
            return """
            Suggest nice-to-see spots for travelers that like sports. \
            Unique or famous spots, like historical sites related to sports or sports figures, \
            stadiums and active venues locals actually use. Prioritize sites that are special to the city or country.
            """
        case .nightlife:
            return """
            Bars, karaoke rooms, late-night clubs and venues \
            that have great reputation. Prioritize sites that are special to the city or country.
            """
        case .cafes:
            return """
            Independent specialty coffee, neighborhood cafes, quiet study rooms, \
            slow breakfast spots. Skip chains and lobby cafés unless specially relevant for tourism or local culture.
            """
        case .art:
            return """
            Galleries, artist-run studios, public murals, design shops, \
            and museums. Mix established institutions with at least two \
            emerging or off-the-main-drag spaces. Prioritize sites that are special to the city or country.
            """
        }
    }
}
