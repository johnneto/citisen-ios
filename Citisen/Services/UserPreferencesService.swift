import Foundation
import Observation
import SwiftUI

@Observable
final class UserPreferencesService {
    private enum Keys {
        static let onboardingComplete = "citisen.onboardingComplete"
        static let modesJSON = "citisen.activeModes"
        static let activeModeIndex = "citisen.activeModeIndex"
        static let darkMode = "citisen.darkMode"
        static let metricUnits = "citisen.metricUnits"
        static let notificationsEnabled = "citisen.notificationsEnabled"
        static let recentSearches = "citisen.recentSearches"
        static let activeCityId = "citisen.activeCityId"
        static let locationRequested = "citisen.locationRequested"
        static let lastSessionCityId = "citisen.lastSessionCityId"
        static let lastDynamicCity = "citisen.lastDynamicCity"
    }

    enum AppearanceOverride: String, CaseIterable, Codable, Identifiable {
        case system, light, dark
        var id: String { rawValue }

        var label: String {
            switch self {
            case .system: return "System"
            case .light: return "Light"
            case .dark: return "Dark"
            }
        }

        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }

    var onboardingComplete: Bool {
        didSet { defaults.set(onboardingComplete, forKey: Keys.onboardingComplete) }
    }

    var activeModes: [TravelMode] {
        didSet { persistModes() }
    }

    var activeModeIndex: Int {
        didSet { defaults.set(activeModeIndex, forKey: Keys.activeModeIndex) }
    }

    var appearance: AppearanceOverride {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.darkMode) }
    }

    var metricUnits: Bool {
        didSet { defaults.set(metricUnits, forKey: Keys.metricUnits) }
    }

    var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Keys.notificationsEnabled) }
    }

    var recentSearches: [String] {
        didSet { persistRecents() }
    }

    var activeCityId: String {
        didSet { defaults.set(activeCityId, forKey: Keys.activeCityId) }
    }

    var locationRequested: Bool {
        didSet { defaults.set(locationRequested, forKey: Keys.locationRequested) }
    }

    /// City id used during the most recent successful spot fetch. Compared against
    /// the user's current city on launch to decide whether cached spots can be reused
    /// without calling Gemini.
    var lastSessionCityId: String? {
        didSet { defaults.set(lastSessionCityId, forKey: Keys.lastSessionCityId) }
    }

    /// Last reverse-geocoded dynamic city. Restored on launch so `CityService.activeCity`
    /// is correct before the geocoder finishes resolving the user's current coordinate —
    /// otherwise cache lookups race against a hardcoded fallback id.
    var lastDynamicCity: City? {
        didSet {
            if let city = lastDynamicCity, let data = try? JSONEncoder().encode(city) {
                defaults.set(data, forKey: Keys.lastDynamicCity)
            } else {
                defaults.removeObject(forKey: Keys.lastDynamicCity)
            }
        }
    }

    var user: UserProfile = .placeholder

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.onboardingComplete = defaults.bool(forKey: Keys.onboardingComplete)
        self.activeModeIndex = defaults.object(forKey: Keys.activeModeIndex) as? Int ?? 2
        self.metricUnits = defaults.object(forKey: Keys.metricUnits) as? Bool ?? true
        self.notificationsEnabled = defaults.bool(forKey: Keys.notificationsEnabled)
        self.activeCityId = defaults.string(forKey: Keys.activeCityId) ?? City.tallinn.id
        self.locationRequested = defaults.bool(forKey: Keys.locationRequested)
        self.lastSessionCityId = defaults.string(forKey: Keys.lastSessionCityId)

        if let data = defaults.data(forKey: Keys.lastDynamicCity),
           let decoded = try? JSONDecoder().decode(City.self, from: data) {
            self.lastDynamicCity = decoded
        } else {
            self.lastDynamicCity = nil
        }

        if let raw = defaults.string(forKey: Keys.darkMode),
           let override = AppearanceOverride(rawValue: raw) {
            self.appearance = override
        } else {
            self.appearance = .system
        }

        if let data = defaults.data(forKey: Keys.modesJSON),
           let decoded = try? JSONDecoder().decode([TravelMode].self, from: data),
           decoded.count == 4 {
            self.activeModes = decoded
        } else {
            self.activeModes = [.food, .nature, .turbo, .history]
        }

        if let data = defaults.data(forKey: Keys.recentSearches),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            self.recentSearches = decoded
        } else {
            self.recentSearches = ["Old Town", "Telliskivi", "Raeko"]
        }
    }

    /// The tab-bar order with `.standard` pinned at index 2 and user modes around it.
    var tabBarOrder: [TravelMode] {
        guard activeModes.count == 4 else {
            return [.food, .nature, .standard, .turbo, .history]
        }
        return [activeModes[0], activeModes[1], .standard, activeModes[2], activeModes[3]]
    }

    var activeMode: TravelMode {
        let order = tabBarOrder
        let clamped = max(0, min(activeModeIndex, order.count - 1))
        return order[clamped]
    }

    func setActiveMode(_ mode: TravelMode) {
        if let idx = tabBarOrder.firstIndex(of: mode) {
            activeModeIndex = idx
        }
    }

    func replaceSlot(_ slotIndex: Int, with mode: TravelMode) {
        guard activeModes.indices.contains(slotIndex) else { return }
        // Prevent duplicates — swap if the incoming mode already exists elsewhere.
        if let existing = activeModes.firstIndex(of: mode) {
            activeModes.swapAt(existing, slotIndex)
        } else {
            activeModes[slotIndex] = mode
        }
    }

    func pushRecentSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var list = recentSearches.filter { $0.caseInsensitiveCompare(trimmed) != .orderedSame }
        list.insert(trimmed, at: 0)
        recentSearches = Array(list.prefix(10))
    }

    func clearRecentSearches() {
        recentSearches = []
    }

    private func persistModes() {
        if let data = try? JSONEncoder().encode(activeModes) {
            defaults.set(data, forKey: Keys.modesJSON)
        }
    }

    private func persistRecents() {
        if let data = try? JSONEncoder().encode(recentSearches) {
            defaults.set(data, forKey: Keys.recentSearches)
        }
    }
}
