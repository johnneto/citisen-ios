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
            let id = String(format: "dyn_%.2f_%.2f", coord.latitude, coord.longitude)

            let resolved = City(
                id: id,
                name: name,
                country: country,
                emojiFlag: "",
                center: Coordinate(latitude: coord.latitude, longitude: coord.longitude),
                defaultSpanKm: 6
            )
            self.dynamicCity = resolved
        } catch is CancellationError {
            return
        } catch {
            AppLog.location.error("Reverse geocode failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
