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
        static let maxSpotsPerRequest = 20
        static let placesConcurrency = 4
        static let searchAreaTriggerMeters: CLLocationDistance = 1_000
        static let maxPhotosPerPlace = 5
        static let photoMaxWidthPx = 1_200
        static let photoMaxHeightPx = 800
    }

    enum Endpoints {
        static let geminiBase = "https://generativelanguage.googleapis.com/v1beta"
        static let geminiModel = "gemini-2.5-flash"
        static var geminiGenerateContent: String {
            "\(geminiBase)/models/\(geminiModel):generateContent"
        }

        static let placesBase = "https://places.googleapis.com/v1"
        static let placesSearchText = "\(placesBase)/places:searchText"
        static let placesDetailsBase = "\(placesBase)/places"

        private static let placeFieldPaths = [
            "id", "displayName", "formattedAddress", "location",
            "rating", "userRatingCount", "priceLevel", "types",
            "regularOpeningHours", "currentOpeningHours", "websiteUri",
            "nationalPhoneNumber", "internationalPhoneNumber",
            "reviews", "editorialSummary", "photos"
        ]

        static let searchTextFieldMask = placeFieldPaths
            .map { "places.\($0)" }
            .joined(separator: ",")
        static let placeDetailsFieldMask = placeFieldPaths.joined(separator: ",")
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
