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
    var activeSubFilters: Set<SubFilter> = []
    var shouldShowLocationDeniedSettings: Bool = false

    private(set) var places: [Place] = []
    private(set) var phase: Phase = .idle
    var visibleRegion: MKCoordinateRegion?
    var mapHeading: Double = 0

    let placesService: PlacesService
    let prefs: UserPreferencesService
    let cityService: CityService
    let locationService: LocationService

    private var loadTask: Task<Void, Never>?
    private var hasCenteredOnUser: Bool = false

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

    func filteredPlaces() -> [Place] {
        places.filter { place in
            activeSubFilters.allSatisfy { $0.matches(place) }
        }
    }

    /// User-initiated fetch (empty-state CTA, retry button). Streams from the
    /// backend, which calls Gemini when no cache is available.
    func fetchSuggestions(forceRefresh: Bool = false) {
        loadTask?.cancel()
        let city = cityService.activeCity
        let mode = prefs.activeMode

        phase = .loading
        places = []
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
                    self.places = collected
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
            places = cached
            phase = .loaded
            return
        }
        places = []
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
