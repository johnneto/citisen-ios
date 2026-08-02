import Foundation

/// Works out which language Google Places should render place names in.
///
/// Places (New) localizes `displayName` to the request's `languageCode` and, when
/// the listing has no name in that language, falls back to whatever name is stored
/// on the listing itself. For crowd-edited landmarks that fallback is sometimes in
/// an unrelated language — Granada's Plaza Nueva came back as "누에바광장". Asking
/// for the city's own language yields the name printed on the local Google Maps
/// listing, which is also the name the Gemini prompt asks for, so curated names and
/// Google names stay comparable for `PlaceResolutionScorer`.
enum PlaceLocale {
    /// ISO 639 language most likely spoken in `countryCode` ("ES" → "es"), resolved
    /// through ICU's likely-subtags data rather than a hand-maintained table.
    static func languageCode(forCountryCode countryCode: String?) -> String? {
        guard let raw = countryCode?.trimmingCharacters(in: .whitespaces),
              raw.count == 2 else { return nil }
        let maximal = Locale.Language(identifier: "und-\(raw.uppercased())").maximalIdentifier
        guard let language = Locale.Language(identifier: maximal).languageCode?.identifier,
              language != "und" else { return nil }
        return language
    }

    static func languageCode(for city: City) -> String? {
        languageCode(forCountryCode: city.countryCode)
    }

    /// Recovers the country code from ids minted by `City.stableId(name:countryCode:)`
    /// ("dyn_granada_es" → "ES"), for call sites that only carry a city id. Legacy
    /// fixture ids ("lisbon") and country-less ids yield nil, leaving those requests
    /// unlocalized exactly as before.
    static func countryCode(fromCityId cityId: String) -> String? {
        guard cityId.hasPrefix("dyn_") else { return nil }
        let parts = cityId.split(separator: "_")
        guard parts.count >= 3, let last = parts.last, last.count == 2 else { return nil }
        return String(last).uppercased()
    }

    static func languageCode(forCityId cityId: String) -> String? {
        languageCode(forCountryCode: countryCode(fromCityId: cityId))
    }
}
