import CoreLocation
import Observation
import os

@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    var authorizationStatus: CLAuthorizationStatus
    var currentLocation: CLLocationCoordinate2D?
    var currentHeading: CLHeading?
    var lastError: String?

    private let manager: CLLocationManager

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

    func startUpdating() {
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.stopUpdatingHeading()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        AppLog.location.info("Authorization changed: \(self.authorizationStatus.rawValue)")
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
            if CLLocationManager.headingAvailable() {
                manager.startUpdatingHeading()
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        currentLocation = last.coordinate
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else { return }
        currentHeading = newHeading
    }

    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        false
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        lastError = error.localizedDescription
        AppLog.location.error("Location error: \(error.localizedDescription, privacy: .public)")
    }
}
