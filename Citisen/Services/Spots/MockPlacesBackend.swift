import CoreLocation
import Foundation

final class MockPlacesBackend: PlacesBackend {
    func loadSpots(
        city: City,
        mode: TravelMode,
        viewport: Viewport?,
        forceRefresh: Bool
    ) async throws -> [Place] {
        let candidates = MockSeed.places(for: city, mode: mode)
        let origin = city.center.clLocation
        return candidates.sorted { lhs, rhs in
            lhs.distance(from: origin) < rhs.distance(from: origin)
        }
    }

    func streamSpots(
        city: City,
        mode: TravelMode,
        viewport: Viewport?,
        forceRefresh: Bool
    ) -> AsyncThrowingStream<Place, Error> {
        AsyncThrowingStream { continuation in
            let task = Task { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
                do {
                    let places = try await self.loadSpots(
                        city: city,
                        mode: mode,
                        viewport: viewport,
                        forceRefresh: forceRefresh
                    )
                    for place in places {
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

    func resolveSearchResult(
        placeId: String,
        sessionToken: String?,
        cityId: String,
        mode: TravelMode
    ) async -> Place? {
        MockSeed.allPlaces.first {
            $0.googlePlaceId == placeId || $0.id.uuidString == placeId
        }
    }

    func resolvePlace(id: UUID) async -> Place? {
        MockSeed.allPlaces.first { $0.id == id }
    }

    func resolvePlaceResult(
        id: UUID,
        googlePlaceId: String?,
        cityId: String?,
        mode: TravelMode?
    ) async -> PlaceResolution {
        if let place = MockSeed.allPlaces.first(where: { $0.id == id }) {
            return .found(place)
        }
        return .notFound
    }

    func enrichPlace(_ place: Place) async -> Place? { nil }

    func clearCache(forCityId cityId: String) {}

    func cachedSpots(city: City, mode: TravelMode) -> [Place]? { nil }
}
