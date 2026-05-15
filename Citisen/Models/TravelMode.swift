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

    var promptInstructions: String {
        switch self {
        case .standard:
            return """
            Curate a balanced sampler of the city: one iconic-but-loved viewpoint, \
            two beloved neighborhood spots (food or café), one cultural site, \
            one piece of green space. Skip checklist items locals roll their eyes at.
            """
        case .food:
            return """
            Focus on independently owned restaurants beloved by residents. \
            Mix price tiers, include at least one regional specialty, \
            one casual daytime spot, one dinner spot. \
            Exclude hotel restaurants and chains.
            """
        case .nature:
            return """
            Surface parks, urban gardens, riverside walks, coastal viewpoints, \
            quiet green pockets. Prioritize places where locals decompress, \
            not Instagram-famous overlooks.
            """
        case .turbo:
            return """
            Pick spots that are walkable from each other and reward a quick \
            visit (30–45 min each). Group geographically. \
            Skip anything that requires reservations or long queues.
            """
        case .history:
            return """
            Prioritize layered, lesser-known historic sites: minor museums, \
            period architecture residents walk past daily, plaques, \
            neighborhoods with preserved character. \
            Skip the top-3 monuments unless context-rich.
            """
        case .sports:
            return """
            Surface running tracks, public courts, climbing gyms, swim spots, \
            cycling routes, and active venues locals actually use. \
            Avoid spectator-only stadiums unless community-run.
            """
        case .nightlife:
            return """
            Surface bars, listening rooms, late-night cafés, and small venues \
            that locals 25–40 actually frequent. \
            Avoid hostel bars, tourist clubs, blog top-10 lists.
            """
        case .cafes:
            return """
            Independent specialty coffee, neighborhood cafés, quiet study rooms, \
            slow breakfast spots. Skip chains and lobby cafés.
            """
        case .art:
            return """
            Galleries, artist-run studios, public murals, design shops, \
            small museums. Mix established institutions with at least two \
            emerging or off-the-main-drag spaces.
            """
        }
    }
}
