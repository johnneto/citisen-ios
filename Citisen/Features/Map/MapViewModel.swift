import CoreLocation
import MapKit
import Observation
import SwiftUI

@Observable
@MainActor
final class MapViewModel {
    enum Phase: Equatable {
        case idle
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
    private(set) var lastFetchCenter: CLLocationCoordinate2D?
    var visibleRegion: MKCoordinateRegion?

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

    func reload(forceRefresh: Bool = false) {
        loadTask?.cancel()
        let city = cityService.activeCity
        let mode = prefs.activeMode
        let viewport = currentViewport(for: city)

        cityService.updateFromCoordinate(viewport.center)

        phase = .loading
        places = []
        loadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let stream = self.placesService.streamSpots(
                city: city,
                mode: mode,
                viewport: viewport,
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
                    self.lastFetchCenter = viewport.center
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

    /// Cold-start entry point. If the user is still in the same city as the previous
    /// session and a valid cached spot list exists, restore it immediately without
    /// calling Gemini. Otherwise fall through to a normal `reload()`.
    func loadInitial() {
        let city = cityService.activeCity
        let mode = prefs.activeMode

        if prefs.lastSessionCityId == city.id,
           let cached = placesService.cachedSpots(city: city, mode: mode) {
            places = cached
            phase = .loaded
            lastFetchCenter = currentViewport(for: city).center
            return
        }

        reload()
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
        loadInitial()
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

    func shouldOfferSearchThisArea() -> Bool {
        guard let region = visibleRegion, let last = lastFetchCenter else { return false }
        let distance = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
            .distance(from: CLLocation(latitude: last.latitude, longitude: last.longitude))
        return distance > AppConfig.Spots.searchAreaTriggerMeters
    }

    private func currentViewport(for city: City) -> Viewport {
        if let region = visibleRegion {
            return Viewport(region: region)
        }
        let delta = city.defaultSpanKm / 111
        return Viewport(
            center: city.center.clLocation,
            latitudeDelta: delta,
            longitudeDelta: delta
        )
    }
}
