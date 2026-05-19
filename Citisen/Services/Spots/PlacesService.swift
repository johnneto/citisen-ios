import Foundation
import Observation

@Observable
@MainActor
final class PlacesService {
    private(set) var snapshot: [UUID: Place] = [:]
    private let backend: any PlacesBackend

    init(backend: any PlacesBackend) {
        self.backend = backend
    }

    func loadSpots(
        city: City,
        mode: TravelMode,
        viewport: Viewport?,
        forceRefresh: Bool
    ) async throws -> [Place] {
        let places = try await backend.loadSpots(
            city: city,
            mode: mode,
            viewport: viewport,
            forceRefresh: forceRefresh
        )
        ingest(places)
        return places
    }

    func streamSpots(
        city: City,
        mode: TravelMode,
        viewport: Viewport?,
        forceRefresh: Bool
    ) -> AsyncThrowingStream<Place, Error> {
        let upstream = backend.streamSpots(
            city: city,
            mode: mode,
            viewport: viewport,
            forceRefresh: forceRefresh
        )
        return AsyncThrowingStream { continuation in
            let task = Task { @MainActor [weak self] in
                do {
                    for try await place in upstream {
                        self?.snapshot[place.id] = place
                        continuation.yield(place)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func search(query: String, city: City) async -> [Place] {
        let results = await backend.search(query: query, city: city)
        ingest(results)
        return results
    }

    func place(id: UUID) -> Place? {
        snapshot[id]
    }

    func resolvePlace(id: UUID) async -> Place? {
        if let cached = snapshot[id] { return cached }
        if let resolved = await backend.resolvePlace(id: id) {
            snapshot[id] = resolved
            return resolved
        }
        return nil
    }

    func resolvePlaceResult(
        id: UUID,
        googlePlaceId: String?,
        cityId: String?,
        mode: TravelMode?
    ) async -> PlaceResolution {
        if let cached = snapshot[id] { return .found(cached) }
        let result = await backend.resolvePlaceResult(
            id: id,
            googlePlaceId: googlePlaceId,
            cityId: cityId,
            mode: mode
        )
        if case .found(let place) = result {
            snapshot[id] = place
        }
        return result
    }

    func clearCache(forCityId cityId: String) {
        backend.clearCache(forCityId: cityId)
        snapshot = snapshot.filter { $0.value.cityId != cityId }
    }

    /// Returns cached spots for the given city + mode without making any network
    /// calls, ingesting them into the in-memory snapshot. Used to restore the
    /// previous session's results on cold start.
    func cachedSpots(city: City, mode: TravelMode) -> [Place]? {
        guard let places = backend.cachedSpots(city: city, mode: mode) else { return nil }
        ingest(places)
        return places
    }

    private func ingest(_ places: [Place]) {
        for place in places {
            snapshot[place.id] = place
        }
    }
}
