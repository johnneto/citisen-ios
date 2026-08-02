import CoreLocation
import MapKit
import Observation
import SwiftUI

@Observable
@MainActor
final class MapViewModel {
    enum Phase: Equatable {
        case idle
        /// No cached spots for the active city — the empty-state CTA invites the
        /// user to explicitly fetch suggestions (no automatic Gemini call).
        case idleNeedsFetch
        case loading
        case streaming
        case loaded
        case error(String)
    }

    var cameraPosition: MapCameraPosition
    var activeSubFilters: Set<SubFilter> = [] {
        didSet {
            guard activeSubFilters != oldValue else { return }
            rebuildFilteredPlaces()
        }
    }
    var shouldShowLocationDeniedSettings: Bool = false

    /// Everything the map renders: the curated list plus the searched places the
    /// user kept for this city + mode.
    private(set) var places: [Place] = []
    /// `places` after the sub-filters, cached rather than recomputed on demand.
    /// The `Map` content closure is re-evaluated continuously while the camera
    /// binding streams during a pinch, so re-filtering (and re-allocating the id
    /// list) per pass showed up as stutter mid-gesture.
    private(set) var filteredPlaces: [Place] = []
    private(set) var filteredPlaceIds: [UUID] = []
    /// Curated spots only. `phase` is derived from this alone, so a city with
    /// kept places but no AI list still shows the "Discover <City>" CTA.
    private var curatedPlaces: [Place] = []
    private(set) var phase: Phase = .idle
    /// City to offer as a new destination after the user tapped Near Me while a
    /// different city was pinned. Nil whenever no offer is pending.
    private(set) var locationSuggestion: City?
    // `@ObservationIgnored`: written on every map-camera frame during pan/tilt
    // but only ever read on POI selection (for span). Observing it would re-evaluate
    // the `Map` content closure 60×/sec and flicker the pin shadows.
    @ObservationIgnored var visibleRegion: MKCoordinateRegion?

    let placesService: PlacesService
    let prefs: UserPreferencesService
    let cityService: CityService
    let locationService: LocationService

    private var loadTask: Task<Void, Never>?
    private var hasCenteredOnUser: Bool = false
    @ObservationIgnored private var isAwaitingLocationCity: Bool = false
    @ObservationIgnored private var locationSuggestionTask: Task<Void, Never>?

    init(
        places: PlacesService,
        prefs: UserPreferencesService,
        cityService: CityService,
        locationService: LocationService
    ) {
        self.placesService = places
        self.prefs = prefs
        self.cityService = cityService
        self.locationService = locationService

        let city = cityService.activeCity
        self.cameraPosition = .region(MKCoordinateRegion(
            center: city.center.clLocation,
            span: MKCoordinateSpan(
                latitudeDelta: city.defaultSpanKm / 111,
                longitudeDelta: city.defaultSpanKm / 111
            )
        ))
    }

    private func rebuildFilteredPlaces() {
        filteredPlaces = places.filter { place in
            activeSubFilters.allSatisfy { $0.matches(place) }
        }
        filteredPlaceIds = filteredPlaces.map(\.id)
    }

    /// Recomputes the rendered list from the curated spots plus the kept ones.
    /// Curated order is preserved (it carries the Gemini ranking); kept places
    /// are appended alphabetically so their pins don't reshuffle between runs.
    private func rebuildPlaces() {
        let kept = placesService
            .keptSpots(cityId: cityService.activeCity.id, mode: prefs.activeMode)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        // Curated first, so a spot the AI also suggested keeps its ranked slot
        // and its curated rationale rather than the kept copy.
        places = (curatedPlaces + kept).uniquedById()
        rebuildFilteredPlaces()
    }

    /// Called when the user keeps a searched place, so its pin becomes permanent
    /// without waiting for a city or mode change.
    func noteKeptSpotsChanged() {
        rebuildPlaces()
    }

    /// User-initiated fetch (empty-state CTA, retry button). Streams from the
    /// backend, which calls Gemini when no cache is available.
    func fetchSuggestions(forceRefresh: Bool = false) {
        loadTask?.cancel()
        let city = cityService.activeCity
        let mode = prefs.activeMode

        phase = .loading
        curatedPlaces = []
        rebuildPlaces()
        loadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let stream = self.placesService.streamSpots(
                city: city,
                mode: mode,
                viewport: nil,
                forceRefresh: forceRefresh
            )
            var collected: [Place] = []
            do {
                for try await place in stream {
                    if Task.isCancelled { return }
                    collected.append(place)
                    self.curatedPlaces = collected
                    self.rebuildPlaces()
                    if self.phase != .streaming {
                        self.phase = .streaming
                    }
                }
                if Task.isCancelled { return }
                if collected.isEmpty {
                    self.phase = .error("No spots found here. Try a different mode or area.")
                } else {
                    self.phase = .loaded
                    self.prefs.lastSessionCityId = city.id
                }
            } catch is CancellationError {
                return
            } catch let spotsError as SpotsError {
                if Task.isCancelled { return }
                self.phase = .error(spotsError.errorDescription ?? "Couldn't load spots.")
            } catch {
                if Task.isCancelled { return }
                self.phase = .error(error.localizedDescription)
            }
        }
    }

    /// Cold-start entry point. Loads cached spots for the active city/mode if
    /// available, otherwise sits in `idleNeedsFetch` waiting for the user to tap
    /// the empty-state CTA. Never auto-triggers a Gemini call.
    func loadInitial() {
        applyCacheOrIdle()
    }

    /// Called when the active city changes (switcher tap, search result, or a
    /// reverse-geocode that resolved a different city). Recenters the camera on
    /// the new city, cancels any in-flight fetch, and surfaces cached spots when
    /// available — otherwise asks the user to fetch.
    func handleCityChange() {
        loadTask?.cancel()
        clearLocationSuggestion()
        recenterOnCity()
        applyCacheOrIdle()
    }

    func applyCacheOrIdle() {
        // Cancel any in-flight load — otherwise a prior mode's stream can yield
        // after this call, flipping phase back to .streaming and hiding the
        // empty-state CTA the user expects to see after switching modes.
        loadTask?.cancel()
        loadTask = nil
        let city = cityService.activeCity
        let mode = prefs.activeMode
        if let cached = placesService.cachedSpots(city: city, mode: mode), !cached.isEmpty {
            curatedPlaces = cached
            rebuildPlaces()
            phase = .loaded
            return
        }
        curatedPlaces = []
        rebuildPlaces()
        phase = .idleNeedsFetch
    }

    func toggleSubFilter(_ filter: SubFilter) {
        if activeSubFilters.contains(filter) {
            activeSubFilters.remove(filter)
        } else {
            activeSubFilters.insert(filter)
        }
    }

    func recenterOnUser() -> Bool {
        switch locationService.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if let coord = locationService.currentLocation {
                cameraPosition = .region(MKCoordinateRegion(
                    center: coord,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                ))
                cityService.updateFromCoordinate(coord)
            } else {
                locationService.startUpdating()
            }
            beginLocationSuggestion()
            return true
        case .notDetermined:
            locationService.requestWhenInUse()
            return true
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    func centerOnUserIfAvailable() {
        guard !hasCenteredOnUser, let coord = locationService.currentLocation else { return }
        hasCenteredOnUser = true
        cameraPosition = .region(MKCoordinateRegion(
            center: coord,
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        ))
        cityService.updateFromCoordinate(coord)
        // Don't call loadInitial here — the citySelectionEpoch onChange in
        // MapScreen will call handleCityChange() once the geocode resolves.
        applyCacheOrIdle()
    }

    func recenterOnCity() {
        let city = cityService.activeCity
        cameraPosition = .region(MKCoordinateRegion(
            center: city.center.clLocation,
            span: MKCoordinateSpan(
                latitudeDelta: city.defaultSpanKm / 111,
                longitudeDelta: city.defaultSpanKm / 111
            )
        ))
    }
}

// MARK: - "Travel to where I actually am" offer

extension MapViewModel {
    /// Near Me only moves the camera — a pinned city stays pinned. When the
    /// device turns out to be in a *different* city, offer to move the trip
    /// there rather than silently doing it (or silently ignoring it).
    private func beginLocationSuggestion() {
        guard cityService.isCityPinned else { return }
        if evaluateLocationSuggestion() { return }
        // The reverse geocode is still in flight. `noteDynamicCityResolved()`
        // retries once it lands; the timer closes the window so a much later,
        // unrelated geocode can't raise a surprise card.
        isAwaitingLocationCity = true
        locationSuggestionTask?.cancel()
        locationSuggestionTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            guard let self, !Task.isCancelled else { return }
            self.isAwaitingLocationCity = false
        }
    }

    /// Raises the offer when the geocoded city differs from the pinned one.
    /// Returns whether an offer is now showing.
    @discardableResult
    private func evaluateLocationSuggestion() -> Bool {
        guard cityService.isCityPinned,
              let candidate = cityService.dynamicCity,
              candidate.id != cityService.activeCity.id else { return false }
        isAwaitingLocationCity = false
        locationSuggestionTask?.cancel()
        locationSuggestion = candidate
        return true
    }

    /// Called by `MapScreen` when the reverse geocode produces a new city, so a
    /// Near Me tap that landed before the geocode still gets its offer.
    func noteDynamicCityResolved() {
        guard isAwaitingLocationCity else { return }
        isAwaitingLocationCity = false
        evaluateLocationSuggestion()
    }

    /// Hands the trip back to the device's real location. `unpinCity()` bumps the
    /// selection epoch, which recentres the camera and fires the welcome overlay.
    func acceptLocationSuggestion() {
        clearLocationSuggestion()
        cityService.unpinCity()
    }

    func clearLocationSuggestion() {
        isAwaitingLocationCity = false
        locationSuggestionTask?.cancel()
        locationSuggestionTask = nil
        if locationSuggestion != nil { locationSuggestion = nil }
    }
}
