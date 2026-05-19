import CoreLocation
import Foundation

struct City: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let country: String
    let emojiFlag: String
    let center: Coordinate
    let defaultSpanKm: Double
    /// ISO 3166-1 alpha-2 country code (e.g. "EE", "FI"). Optional so older cached
    /// `City` payloads decoded from `lastDynamicCity`/`recentCities` keep working.
    let countryCode: String?

    init(
        id: String,
        name: String,
        country: String,
        emojiFlag: String,
        center: Coordinate,
        defaultSpanKm: Double,
        countryCode: String? = nil
    ) {
        self.id = id
        self.name = name
        self.country = country
        self.emojiFlag = emojiFlag
        self.center = center
        self.defaultSpanKm = defaultSpanKm
        self.countryCode = countryCode
    }

    var displayName: String {
        "\(name), \(country)"
    }

    /// Best-available flag emoji: stored value if present, otherwise derived from
    /// the ISO country code via regional indicator scalars, falling back to a globe.
    var flagEmoji: String {
        if !emojiFlag.isEmpty { return emojiFlag }
        if let code = countryCode, code.count == 2 {
            let base: UInt32 = 127397
            let scalars = code.uppercased().unicodeScalars.compactMap {
                UnicodeScalar(base + $0.value)
            }
            if scalars.count == 2 {
                return String(String.UnicodeScalarView(scalars))
            }
        }
        return "🌐"
    }
}

extension City {
    /// Stable id for a city resolved from coordinates or selected via Places search.
    /// Mirrors the previous `dyn_` scheme so existing dynamic-city caches keep matching,
    /// but uses the country code prefix to disambiguate same-named cities across borders.
    static func stableId(name: String, countryCode: String) -> String {
        let slug = name
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: " ", with: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
        let countrySlug = countryCode.lowercased()
        if !slug.isEmpty, !countrySlug.isEmpty {
            return "dyn_\(slug)_\(countrySlug)"
        }
        if !slug.isEmpty {
            return "dyn_\(slug)"
        }
        return "dyn_current"
    }
}

// MARK: - Legacy hardcoded fixtures
//
// Kept around because Mock seed data (`MockSeed.places(for:)`), saved-spot
// fallbacks (`SavedSpotEntity`), and route titles still reference these by
// dot-syntax. They are no longer the runtime source of switcher cities —
// the switcher reads `prefs.recentCities` instead.

extension City {
    static let tallinn = City(
        id: "tallinn",
        name: "Tallinn",
        country: "Estonia",
        emojiFlag: "🇪🇪",
        center: Coordinate(latitude: 59.4370, longitude: 24.7536),
        defaultSpanKm: 6,
        countryCode: "EE"
    )

    static let tartu = City(
        id: "tartu",
        name: "Tartu",
        country: "Estonia",
        emojiFlag: "🇪🇪",
        center: Coordinate(latitude: 58.3780, longitude: 26.7290),
        defaultSpanKm: 5,
        countryCode: "EE"
    )

    static let helsinki = City(
        id: "helsinki",
        name: "Helsinki",
        country: "Finland",
        emojiFlag: "🇫🇮",
        center: Coordinate(latitude: 60.1699, longitude: 24.9384),
        defaultSpanKm: 8,
        countryCode: "FI"
    )

    static let riga = City(
        id: "riga",
        name: "Riga",
        country: "Latvia",
        emojiFlag: "🇱🇻",
        center: Coordinate(latitude: 56.9496, longitude: 24.1052),
        defaultSpanKm: 7,
        countryCode: "LV"
    )

    static let all: [City] = [.tallinn, .tartu, .helsinki, .riga]
}
