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

    /// True when the user has deliberately picked a city, which then outranks the
    /// reverse-geocoded `dynamicCity`.
    var isCityPinned: Bool {
        prefs.cityPinned
    }

    var activeCity: City {
        // A deliberate pick wins over GPS — otherwise the next reverse-geocode
        // silently drags the trip back to wherever the phone physically is.
        if prefs.cityPinned,
           let pinned = prefs.recentCities.first(where: { $0.id == prefs.activeCityId }) {
            return pinned
        }
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

    /// User picked a city from the switcher or from search. Records it in recents,
    /// pins it against GPS, and bumps the selection epoch. The welcome animation is
    /// driven separately by `MapScreen`, which has access to `lastSessionCityId`.
    ///
    /// `dynamicCity` is deliberately left populated — it still tracks the real
    /// device location, it just loses the precedence contest while pinned, so
    /// `unpinCity()` can restore it instantly.
    func setActiveCity(_ city: City) {
        prefs.activeCityId = city.id
        // Must precede the pin so `activeCity`'s recents lookup can resolve it.
        recordRecent(city)
        prefs.cityPinned = true
        citySelectionEpoch &+= 1
    }

    /// Drops the manual pin and hands control back to the reverse-geocoded city.
    func unpinCity() {
        guard prefs.cityPinned else { return }
        let previousId = activeCity.id
        prefs.cityPinned = false
        if activeCity.id != previousId {
            citySelectionEpoch &+= 1
        }
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
            // While pinned the active city is unchanged, so bumping the epoch would
            // fire `handleCityChange()` and yank the camera back off the user right
            // after they tapped Near Me.
            if previousId != resolved.id, !prefs.cityPinned {
                citySelectionEpoch &+= 1
            }
        } catch is CancellationError {
            return
        } catch {
            AppLog.location.error("Reverse geocode failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
