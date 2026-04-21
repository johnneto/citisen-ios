import Foundation

enum AppConfig {
    static let appStoreURLString = "https://apps.apple.com/app/id0000000000"
    static let feedbackEmail = "hello@citisen.app"
    static let privacyURLString = "https://citisen.app/privacy"
    static let termsURLString = "https://citisen.app/terms"
    static let aboutURLString = "https://citisen.app/about"

    static let bundleDisplayName = "Citisen"
}

enum FeatureFlags {
    static let aiCurationEnabled = false
    static let googlePlacesEnabled = false
    static let analyticsEnabled = false
    static let crashReportingEnabled = false
}
