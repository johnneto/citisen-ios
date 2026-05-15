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
        static let maxSpotsPerRequest = 10
        static let placesConcurrency = 4
        static let searchAreaTriggerMeters: CLLocationDistance = 1_000
    }

    enum Endpoints {
        static let geminiBase = "https://generativelanguage.googleapis.com/v1beta"
        static let geminiModel = "gemini-2.5-flash"
        static var geminiGenerateContent: String {
            "\(geminiBase)/models/\(geminiModel):generateContent"
        }

        static let placesFindFromText = "https://maps.googleapis.com/maps/api/place/findplacefromtext/json"
        static let placesDetails = "https://maps.googleapis.com/maps/api/place/details/json"
        static let placeDetailsFields = [
            "place_id", "name", "formatted_address", "geometry",
            "rating", "user_ratings_total", "price_level", "types",
            "opening_hours", "current_opening_hours", "website",
            "formatted_phone_number", "international_phone_number",
            "reviews", "editorial_summary"
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
    static let analyticsEnabled = false
    static let crashReportingEnabled = false
}
