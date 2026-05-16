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

    func clearCache(forCityId cityId: String) {
        backend.clearCache(forCityId: cityId)
        snapshot = snapshot.filter { $0.value.cityId != cityId }
    }

    private func ingest(_ places: [Place]) {
        for place in places {
            snapshot[place.id] = place
        }
    }
}
