import Foundation
import Observation

@Observable
@MainActor
final class SearchViewModel {
    var query: String = ""
    private(set) var results: [Place] = []

    private let places: PlacesService
    private let prefs: UserPreferencesService
    private let cityService: CityService
    private var searchTask: Task<Void, Never>?

    init(places: PlacesService, prefs: UserPreferencesService, cityService: CityService) {
        self.places = places
        self.prefs = prefs
        self.cityService = cityService
    }

    var recent: [String] { prefs.recentSearches }

    func performSearch() {
        runSearch(query: query)
        if !query.trimmingCharacters(in: .whitespaces).isEmpty {
            prefs.pushRecentSearch(query)
        }
    }

    func onQueryChange(_ newValue: String) {
        query = newValue
        runSearch(query: newValue)
    }

    func applyRecent(_ term: String) {
        query = term
        performSearch()
    }

    func clearRecents() {
        prefs.clearRecentSearches()
    }

    private func runSearch(query: String) {
        searchTask?.cancel()
        let city = cityService.activeCity
        searchTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let found = await self.places.search(query: query, city: city)
            if Task.isCancelled { return }
            self.results = found
        }
    }
}
