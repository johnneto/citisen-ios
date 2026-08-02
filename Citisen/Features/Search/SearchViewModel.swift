import Foundation
import Observation
import os

@Observable
@MainActor
final class SearchViewModel {
    var query: String = "" {
        didSet {
            guard oldValue != query else { return }
            scheduleSearch()
        }
    }

    private(set) var placeSuggestions: [SearchSuggestion] = []
    private(set) var citySuggestions: [SearchSuggestion] = []
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?

    private let places: PlacesService
    private let prefs: UserPreferencesService
    private let cityService: CityService
    private let client: GooglePlacesClient
    private let debounce: UInt64
    private var sessionToken: String = UUID().uuidString
    private var searchTask: Task<Void, Never>?

    init(
        places: PlacesService,
        prefs: UserPreferencesService,
        cityService: CityService,
        client: GooglePlacesClient = GooglePlacesClient(),
        debounceMs: Int = AppConfig.Search.debounceMilliseconds
    ) {
        self.places = places
        self.prefs = prefs
        self.cityService = cityService
        self.client = client
        self.debounce = UInt64(max(0, debounceMs)) * 1_000_000
    }

    var recent: [String] { prefs.recentSearches }

    var hasResults: Bool {
        !placeSuggestions.isEmpty || !citySuggestions.isEmpty
    }

    var isQueryEmpty: Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func applyRecent(_ term: String) {
        query = term
    }

    func clearRecents() {
        prefs.clearRecentSearches()
    }

    func clearQuery() {
        query = ""
    }

    /// Resolves a tapped place suggestion into a full `Place`, ingested into
    /// `PlacesService` so the POI sheet renders without a second fetch. Reuses the
    /// autocomplete session token so Google bills both calls as one session, then
    /// rotates it for the next search.
    func openPlace(_ suggestion: SearchSuggestion) async -> Place? {
        let resolved = await places.resolveSearchResult(
            placeId: suggestion.placeId,
            sessionToken: sessionToken,
            cityId: cityService.activeCity.id,
            mode: prefs.activeMode
        )
        guard let resolved else {
            errorMessage = "Couldn't open that place. Try again."
            return nil
        }
        sessionToken = UUID().uuidString
        prefs.pushRecentSearch(query)
        return resolved
    }

    /// Switches the trip destination to a tapped city suggestion. `CityService`
    /// pins it and bumps `citySelectionEpoch`, which `MapScreen` observes to
    /// recentre the camera and fire the welcome overlay.
    func switchCity(to suggestion: SearchSuggestion) async -> Bool {
        do {
            guard let details = try await client.cityDetails(
                placeId: suggestion.placeId,
                sessionToken: sessionToken
            ), let city = CityMapper.makeCity(from: details, fallbackName: suggestion.primaryText) else {
                errorMessage = "Couldn't load that city. Try again."
                return false
            }
            sessionToken = UUID().uuidString
            prefs.pushRecentSearch(query)
            cityService.setActiveCity(city)
            return true
        } catch {
            AppLog.places.error("cityDetails failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Couldn't load that city. Try again."
            return false
        }
    }

    // MARK: - Internals

    private func scheduleSearch() {
        searchTask?.cancel()
        let snapshot = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard snapshot.count >= AppConfig.Search.minQueryLength else {
            resetResults()
            return
        }

        searchTask = Task { @MainActor [weak self] in
            guard let self else { return }
            if self.debounce > 0 {
                try? await Task.sleep(nanoseconds: self.debounce)
            }
            if Task.isCancelled { return }
            self.isLoading = true
            self.errorMessage = nil
            do {
                let suggestions = try await self.client.autocomplete(
                    query: snapshot,
                    sessionToken: self.sessionToken,
                    near: self.cityService.activeCity.center.clLocation
                )
                if Task.isCancelled { return }
                self.apply(suggestions)
            } catch is CancellationError {
                return
            } catch {
                if Task.isCancelled { return }
                AppLog.places.error("search autocomplete failed: \(error.localizedDescription, privacy: .public)")
                self.placeSuggestions = []
                self.citySuggestions = []
                self.errorMessage = (error as? SpotsError)?.errorDescription ?? "Search failed. Try again."
            }
            if !Task.isCancelled {
                self.isLoading = false
            }
        }
    }

    private func apply(_ suggestions: [AutocompleteSuggestion]) {
        let projected = suggestions.compactMap { SearchSuggestion(from: $0) }
        let limit = AppConfig.Search.maxSuggestions
        citySuggestions = Array(projected.filter { $0.kind == .city }.prefix(limit))
        placeSuggestions = Array(projected.filter { $0.kind == .place }.prefix(limit))
    }

    private func resetResults() {
        placeSuggestions = []
        citySuggestions = []
        isLoading = false
        errorMessage = nil
    }
}
