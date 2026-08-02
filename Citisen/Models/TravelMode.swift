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
            Curate a balanced sampler of the city's best, prioritizing what is interesting for a \
            first-time visitor: signature landmarks, food, viewpoints, culture and local life. \
            Skip hotels and places famous mainly for being tourist traps.
            """
        case .food:
            return """
            Independently owned restaurants residents love. Mix price tiers; include at least \
            5 venues serving regional specialties, plus casual daytime spots and dinner spots. \
            Always prioritize kitchens serving dishes special to the city or country. \
            Exclude hotels and hotel restaurants.
            """
        case .nature:
            return """
            Parks, urban gardens, riverside or coastal walks, viewpoints, famous trails, \
            and quiet green pockets. Prioritize landscapes special to the city or country.
            """
        case .turbo:
            return """
            Only must-see essentials for a short visit: iconic buildings, landmark squares, \
            statues, flagship museums, famous viewpoints. Skip anything a rushed visitor could \
            safely miss; skip hotels unless the building itself is a landmark.
            """
        case .history:
            return """
            Spots tied to historical events, conflicts, famous figures, preserved neighborhoods, \
            architecture highlights, museums and memorials. Include at least 3 lesser-known \
            historical curiosities — obscure relics, oddities, or forgotten sites that reward a detour.
            """
        case .sports:
            return """
            Spots for travelers who love sports: legendary stadiums and arenas, historic sites \
            tied to sports or athletes, and active venues locals actually use. \
            Prioritize venues special to the city or country.
            """
        case .nightlife:
            return """
            Bars, cocktail dens, live-music venues, karaoke rooms, and late-night clubs with \
            strong local reputations. Prioritize venues special to the city or country over \
            generic party spots.
            """
        case .cafes:
            return """
            Independent specialty coffee, beloved neighborhood cafés, quiet rooms good for \
            reading, and slow breakfast spots. Skip chains and hotel lobby cafés unless they \
            are a genuine local institution.
            """
        case .art:
            return """
            Galleries, artist-run studios, public murals and street-art spots, design shops, \
            and art museums. Mix established institutions with at least two emerging or \
            off-the-main-drag spaces. Prioritize scenes special to the city or country.
            """
        }
    }

    /// Google Places (New) Table A primary types Gemini may emit for this mode.
    /// The hint is sent with `strictTypeFiltering: true`, so every value here must be a
    /// valid Table A type — an invalid or wrong hint hides the correct place.
    var typePalette: [String] {
        switch self {
        case .standard:
            return ["tourist_attraction", "historical_landmark", "monument", "museum",
                    "art_gallery", "park", "market", "church", "restaurant", "cafe"]
        case .food:
            return ["restaurant", "bakery", "market", "cafe", "bar"]
        case .nature:
            return ["park", "garden", "botanical_garden", "beach", "hiking_area", "national_park"]
        case .turbo:
            return ["tourist_attraction", "historical_landmark", "monument", "museum",
                    "church", "park", "plaza"]
        case .history:
            return ["historical_landmark", "monument", "museum", "church",
                    "place_of_worship", "cemetery"]
        case .sports:
            return ["stadium", "arena", "sports_complex", "gym", "park", "historical_landmark"]
        case .nightlife:
            return ["bar", "night_club", "karaoke"]
        case .cafes:
            return ["cafe", "coffee_shop", "bakery", "tea_house"]
        case .art:
            return ["art_gallery", "museum", "art_studio", "performing_arts_theater", "cultural_center"]
        }
    }
}
