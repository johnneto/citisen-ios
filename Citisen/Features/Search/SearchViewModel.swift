import Foundation
import Observation

@Observable
@MainActor
final class SearchViewModel {
    var query: String = ""
    private(set) var results: [Place] = []

    private let places: MockPlacesService
    private let prefs: UserPreferencesService
    private let cityService: CityService

    init(places: MockPlacesService, prefs: UserPreferencesService, cityService: CityService) {
        self.places = places
        self.prefs = prefs
        self.cityService = cityService
    }

    var recent: [String] { prefs.recentSearches }

    func performSearch() {
        results = places.search(query: query, city: cityService.activeCity)
        if !query.trimmingCharacters(in: .whitespaces).isEmpty {
            prefs.pushRecentSearch(query)
        }
    }

    func onQueryChange(_ newValue: String) {
        query = newValue
        results = places.search(query: newValue, city: cityService.activeCity)
    }

    func applyRecent(_ term: String) {
        query = term
        performSearch()
    }

    func clearRecents() {
        prefs.clearRecentSearches()
    }
}
