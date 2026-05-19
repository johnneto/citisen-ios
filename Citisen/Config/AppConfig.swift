import CoreLocation
import Foundation

enum AppConfig {
    static let appStoreURLString = "https://apps.apple.com/app/id0000000000"
    static let feedbackEmail = "hello@citisen.app"
    static let privacyURLString = "https://citisen.app/privacy"
    static let termsURLString = "https://citisen.app/terms"
    static let aboutURLString = "https://citisen.app/about"

    static let bundleDisplayName = "Citisen"

    enum Spots {
        static let cacheTTLDays: Double = 30
        static var cacheTTLSeconds: TimeInterval { cacheTTLDays * 86_400 }
        static let minSpotsPerRequest = 20
        static let maxSpotsPerRequest = 60
        static let placesConcurrency = 8
        static let maxPhotosPerPlace = 10
        static let photoMaxWidthPx = 1_200
        static let photoMaxHeightPx = 800
        static let initialPhotoBatchSize = 5
        static let photoBatchIncrement = 5
        static let photoCacheTTLDays: Double = 3
        static var photoCacheTTLSeconds: TimeInterval { photoCacheTTLDays * 86_400 }
        static let photoCacheDiskCapBytes = 75 * 1_024 * 1_024
        static let photoCacheMemoryCapBytes = 30 * 1_024 * 1_024
    }

    enum CitySearch {
        /// Debounce window before firing an autocomplete request as the user types.
        static let debounceMilliseconds: Int = 250
        /// Default span (km) used to recenter the camera on a freshly-selected city.
        static let defaultSpanKm: Double = 8
    }

    enum Endpoints {
        static let geminiBase = "https://generativelanguage.googleapis.com/v1beta"
        static let geminiModel = "gemini-2.5-flash"
        static var geminiGenerateContent: String {
            "\(geminiBase)/models/\(geminiModel):generateContent"
        }

        static let placesBase = "https://places.googleapis.com/v1"
        static let placesSearchText = "\(placesBase)/places:searchText"
        static let placesAutocomplete = "\(placesBase)/places:autocomplete"
        static let placesDetailsBase = "\(placesBase)/places"

        private static let placeFieldPaths = [
            "id", "displayName", "formattedAddress", "location",
            "rating", "userRatingCount", "priceLevel",
            "primaryType", "types",
            "regularOpeningHours", "currentOpeningHours", "websiteUri",
            "nationalPhoneNumber", "internationalPhoneNumber",
            "reviews", "editorialSummary", "photos",
            "businessStatus"
        ]

        static let searchTextFieldMask = placeFieldPaths
            .map { "places.\($0)" }
            .joined(separator: ",")
        static let placeDetailsFieldMask = placeFieldPaths.joined(separator: ",")

        /// Field mask for the lighter city-details payload used after autocomplete
        /// selection — only the fields needed to build a `City`.
        static let cityDetailsFieldMask = [
            "id", "displayName", "location", "addressComponents", "formattedAddress"
        ].joined(separator: ",")
    }

    enum Secrets {
        static let geminiKey = "GEMINI_API_KEY"
        static let googlePlacesKey = "GOOGLE_PLACES_API_KEY"
    }
}

enum FeatureFlags {
    static let aiCurationEnabled = true
    static let googlePlacesEnabled = true
    static let analyticsEnabled = true
    static let crashReportingEnabled = false
}
