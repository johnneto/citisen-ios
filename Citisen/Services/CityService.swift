import CoreLocation
import Foundation
import Observation
import os

@MainActor
@Observable
final class CityService {
    let cities: [City] = City.all
    private(set) var dynamicCity: City?
    private(set) var isResolvingCity: Bool = false
    private(set) var citySelectionEpoch: Int = 0

    private let prefs: UserPreferencesService
    private let geocoder = CLGeocoder()
    private var resolveTask: Task<Void, Never>?

    init(prefs: UserPreferencesService) {
        self.prefs = prefs
        self.dynamicCity = prefs.lastDynamicCity
    }

    var activeCity: City {
        dynamicCity ?? hardcodedCity
    }

    private var hardcodedCity: City {
        cities.first(where: { $0.id == prefs.activeCityId }) ?? City.tallinn
    }

    func setActiveCity(_ city: City) {
        dynamicCity = nil
        prefs.activeCityId = city.id
        citySelectionEpoch &+= 1
    }

    func updateFromCoordinate(_ coord: CLLocationCoordinate2D) {
        resolveTask?.cancel()
        resolveTask = Task { [weak self] in
            guard let self else { return }
            await self.resolve(coord: coord)
        }
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
            let id = stableDynamicId(name: name, countryCode: countryCode)

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
                defaultSpanKm: 6
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

    private func stableDynamicId(name: String, countryCode: String) -> String {
        let slug = name
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: " ", with: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
        let countrySlug = countryCode.lowercased()
        if !slug.isEmpty, !countrySlug.isEmpty {
            return "dyn_\(slug)_\(countrySlug)"
        }
        if !slug.isEmpty {
            return "dyn_\(slug)"
        }
        return "dyn_current"
    }
}
