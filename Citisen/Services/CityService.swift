import CoreLocation
import Foundation
import Observation
import os

@MainActor
@Observable
final class CityService {
    private(set) var dynamicCity: City?
    private(set) var isResolvingCity: Bool = false
    private(set) var citySelectionEpoch: Int = 0

    /// Most recent city that triggered a "welcome" overlay. Increments the
    /// `welcomeEpoch` whenever set so observers can fire the animation.
    /// Suppression and persistence logic lives in `MapScreen`.
    private(set) var pendingWelcomeCity: City?
    private(set) var welcomeEpoch: Int = 0

    private let prefs: UserPreferencesService
    private let geocoder = CLGeocoder()
    private var resolveTask: Task<Void, Never>?

    init(prefs: UserPreferencesService) {
        self.prefs = prefs
        self.dynamicCity = prefs.lastDynamicCity
    }

    var activeCity: City {
        if let dynamicCity { return dynamicCity }
        if let active = prefs.recentCities.first(where: { $0.id == prefs.activeCityId }) {
            return active
        }
        if let first = prefs.recentCities.first {
            return first
        }
        return prefs.lastDynamicCity ?? City.tallinn
    }

    var recentCities: [City] {
        prefs.recentCities
    }

    /// User picked a city from the switcher (recent or search result). Records it
    /// in recents and bumps the selection epoch. The welcome animation is driven
    /// separately by `MapViewModel` which has access to `lastSessionCityId`.
    func setActiveCity(_ city: City) {
        dynamicCity = nil
        prefs.activeCityId = city.id
        recordRecent(city)
        citySelectionEpoch &+= 1
    }

    /// Inserts the city at the front of `recentCities`, de-duped by id, capped at
    /// `UserPreferencesService.maxRecentCities`. Does not change the active city.
    func recordRecent(_ city: City) {
        var list = prefs.recentCities.filter { $0.id != city.id }
        list.insert(city, at: 0)
        if list.count > UserPreferencesService.maxRecentCities {
            list = Array(list.prefix(UserPreferencesService.maxRecentCities))
        }
        prefs.recentCities = list
    }

    func updateFromCoordinate(_ coord: CLLocationCoordinate2D) {
        resolveTask?.cancel()
        resolveTask = Task { [weak self] in
            guard let self else { return }
            await self.resolve(coord: coord)
        }
    }

    func triggerWelcome(for city: City) {
        pendingWelcomeCity = city
        welcomeEpoch &+= 1
    }

    func clearPendingWelcome() {
        pendingWelcomeCity = nil
    }

    private func resolve(coord: CLLocationCoordinate2D) async {
        isResolvingCity = true
        defer { isResolvingCity = false }

        let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            try Task.checkCancellation()
            guard let placemark = placemarks.first else { return }

            let name = placemark.locality
                ?? placemark.subAdministrativeArea
                ?? placemark.administrativeArea
                ?? "Current location"
            let country = placemark.country ?? ""
            let countryCode = placemark.isoCountryCode ?? ""
            let id = City.stableId(name: name, countryCode: countryCode)

            // Keep the cached city centre stable across small GPS jitter — if the resolved
            // city id matches what we already have, don't overwrite the (possibly more
            // representative) previous centre coordinate with this single reading.
            let centerCoord: Coordinate
            if let existing = dynamicCity, existing.id == id {
                centerCoord = existing.center
            } else {
                centerCoord = Coordinate(latitude: coord.latitude, longitude: coord.longitude)
            }

            let resolved = City(
                id: id,
                name: name,
                country: country,
                emojiFlag: "",
                center: centerCoord,
                defaultSpanKm: 6,
                countryCode: countryCode.isEmpty ? nil : countryCode
            )
            let previousId = dynamicCity?.id
            self.dynamicCity = resolved
            prefs.lastDynamicCity = resolved
            if previousId != resolved.id {
                citySelectionEpoch &+= 1
            }
        } catch is CancellationError {
            return
        } catch {
            AppLog.location.error("Reverse geocode failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
