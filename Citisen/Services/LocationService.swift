import CoreLocation
import Observation
import os

@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    var authorizationStatus: CLAuthorizationStatus
    var currentLocation: CLLocationCoordinate2D?
    var lastError: String?

    private let manager: CLLocationManager
    private let geocoder = CLGeocoder()

    override init() {
        self.manager = CLLocationManager()
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestWhenInUse() {
        manager.requestWhenInUseAuthorization()
    }

    func reverseGeocode(location: CLLocation) async throws -> (countryCode: String?, city: String?) {
        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        let placemark = placemarks.first
        return (placemark?.isoCountryCode, placemark?.locality)
    }

    func startUpdating() {
        manager.startUpdatingLocation()
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        AppLog.location.info("Authorization changed: \(self.authorizationStatus.rawValue)")
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        currentLocation = last.coordinate
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        lastError = error.localizedDescription
        AppLog.location.error("Location error: \(error.localizedDescription, privacy: .public)")
    }
}
