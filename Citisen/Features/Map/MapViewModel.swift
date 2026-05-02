import CoreLocation
import MapKit
import Observation
import SwiftUI

@Observable
@MainActor
final class MapViewModel {
    var cameraPosition: MapCameraPosition
    var activeSubFilters: Set<SubFilter> = []
    var shouldShowLocationDeniedSettings: Bool = false

    let places: MockPlacesService
    let prefs: UserPreferencesService
    let cityService: CityService
    let locationService: LocationService

    init(
        places: MockPlacesService,
        prefs: UserPreferencesService,
        cityService: CityService,
        locationService: LocationService
    ) {
        self.places = places
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

    func currentPlaces() -> [Place] {
        places.places(
            city: cityService.activeCity,
            mode: prefs.activeMode,
            subFilters: activeSubFilters
        )
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
