import Foundation

/// Lightweight projection of a Places Autocomplete (New) `placePrediction`
/// suitable for rendering in the city switcher.
struct CityPrediction: Identifiable, Hashable {
    let placeId: String
    let primaryText: String
    let secondaryText: String

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
        self.placeId = placeId
        self.primaryText = prediction.structuredFormat?.mainText?.text
            ?? prediction.text?.text
            ?? ""
        self.secondaryText = prediction.structuredFormat?.secondaryText?.text ?? ""
    }
}
