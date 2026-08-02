import Foundation

enum SearchSuggestionKind {
    case place
    case city
}

/// Projection of a Places Autocomplete (New) `placePrediction` for the unified
/// search screen. Unlike `CityPrediction` — which is city-only by construction —
/// this keeps the prediction's `types` long enough to tell a city apart from a
/// regular place, so both can share one result list.
struct SearchSuggestion: Identifiable, Hashable {
    let placeId: String
    let primaryText: String
    let secondaryText: String
    let kind: SearchSuggestionKind
    let iconSymbol: String

    var id: String { placeId }

    var displayName: String {
        if secondaryText.isEmpty { return primaryText }
        return "\(primaryText), \(secondaryText)"
    }

    init?(from suggestion: AutocompleteSuggestion) {
        guard let prediction = suggestion.placePrediction,
              let placeId = prediction.placeId, !placeId.isEmpty else {
            return nil
        }
        let types = prediction.types ?? []
        self.placeId = placeId
        self.primaryText = prediction.structuredFormat?.mainText?.text
            ?? prediction.text?.text
            ?? ""
        self.secondaryText = prediction.structuredFormat?.secondaryText?.text ?? ""
        self.kind = Self.kind(for: types)
        self.iconSymbol = Self.iconSymbol(for: types, kind: self.kind)
    }

    // MARK: - Classification

    /// Google place types that mean "this is somewhere you travel *to*", not a
    /// spot within a city.
    private static let cityTypes: Set<String> = [
        "locality",
        "postal_town",
        "sublocality",
        "administrative_area_level_1",
        "administrative_area_level_2",
        "administrative_area_level_3",
        "country"
    ]

    private static func kind(for types: [String]) -> SearchSuggestionKind {
        types.contains(where: { cityTypes.contains($0) }) ? .city : .place
    }

    /// Maps the prediction's types onto an SF Symbol, first match wins.
    private static let symbolsByType: [(type: String, symbol: String)] = [
        ("cafe", "cup.and.saucer"),
        ("bakery", "birthday.cake"),
        ("bar", "wineglass"),
        ("night_club", "music.note"),
        ("restaurant", "fork.knife"),
        ("food", "fork.knife"),
        ("museum", "building.columns"),
        ("art_gallery", "paintpalette"),
        ("church", "building.columns"),
        ("tourist_attraction", "star"),
        ("park", "tree"),
        ("natural_feature", "leaf"),
        ("beach", "beach.umbrella"),
        ("lodging", "bed.double"),
        ("hotel", "bed.double"),
        ("gym", "figure.run"),
        ("store", "bag"),
        ("shopping_mall", "bag"),
        ("transit_station", "tram"),
        ("airport", "airplane")
    ]

    private static func iconSymbol(for types: [String], kind: SearchSuggestionKind) -> String {
        if kind == .city { return "globe.europe.africa" }
        let lookup = Set(types)
        for entry in symbolsByType where lookup.contains(entry.type) {
            return entry.symbol
        }
        return "mappin.circle"
    }
}
