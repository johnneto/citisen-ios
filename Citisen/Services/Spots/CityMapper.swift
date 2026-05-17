import Foundation

/// Builds a `City` value from a Places API (New) details payload returned by
/// `GooglePlacesClient.cityDetails(placeId:sessionToken:)`. Falls back to the
/// autocomplete prediction's primary text when the details response omits a
/// localized name.
enum CityMapper {
    static func makeCity(from place: PlaceV1, fallbackName: String) -> City? {
        let name = place.displayName?.text?.trimmingCharacters(in: .whitespaces)
            ?? fallbackName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }

        let components = place.addressComponents ?? []
        let countryComponent = components.first(where: {
            ($0.types ?? []).contains("country")
        })
        let country = countryComponent?.longText ?? ""
        let countryCode = countryComponent?.shortText?.uppercased() ?? ""

        guard let coords = place.location else { return nil }
        let center = Coordinate(latitude: coords.latitude, longitude: coords.longitude)

        let id = City.stableId(name: name, countryCode: countryCode)
        return City(
            id: id,
            name: name,
            country: country,
            emojiFlag: "",
            center: center,
            defaultSpanKm: AppConfig.CitySearch.defaultSpanKm,
            countryCode: countryCode.isEmpty ? nil : countryCode
        )
    }
}
