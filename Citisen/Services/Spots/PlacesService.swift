import Foundation
import Observation

@Observable
@MainActor
final class PlacesService {
    private(set) var snapshot: [UUID: Place] = [:]
    /// Ids of searched places the user has kept. Observing this is how the map
    /// learns to promote a transient search pin into a permanent one.
    private(set) var keptSpotIds: Set<UUID> = []
    /// Places the user declined to keep. Session-only by design — a fresh launch
    /// may offer again, and nothing about a "not now" is worth persisting.
    private(set) var declinedKeepIds: Set<UUID> = []
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

    /// Resolves a search-autocomplete suggestion into a full `Place` and ingests
    /// it, so the POI sheet finds it in `snapshot` without a second round-trip.
    func resolveSearchResult(
        placeId: String,
        sessionToken: String?,
        cityId: String,
        mode: TravelMode
    ) async -> Place? {
        guard let place = await backend.resolveSearchResult(
            placeId: placeId,
            sessionToken: sessionToken,
            cityId: cityId,
            mode: mode
        ) else { return nil }
        snapshot[place.id] = place
        return place
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

    /// Lazily upgrades a cheap-mask place to the full Place Details payload
    /// (reviews, editorial summary) when the POI sheet opens it. Returns the
    /// enriched place, or the original when it is already enriched or the
    /// fetch fails.
    func enrichPlace(_ place: Place) async -> Place {
        guard place.detailsFetchedAt == nil else { return place }
        guard let enriched = await backend.enrichPlace(place) else { return place }
        snapshot[enriched.id] = enriched
        return enriched
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

    // MARK: - Kept searched places

    /// Searched places the user kept for this city + mode, ingested so the POI
    /// sheet and places list resolve them without a network round-trip.
    func keptSpots(cityId: String, mode: TravelMode) -> [Place] {
        let kept = backend.keptSpots(cityId: cityId, mode: mode)
        ingest(kept)
        keptSpotIds.formUnion(kept.map(\.id))
        return kept
    }

    @discardableResult
    func keepSpot(_ place: Place) -> Place {
        let kept = backend.keepSpot(place)
        snapshot[kept.id] = kept
        keptSpotIds.insert(kept.id)
        declinedKeepIds.remove(kept.id)
        return kept
    }

    func declineKeep(id: UUID) {
        declinedKeepIds.insert(id)
    }

    private func ingest(_ places: [Place]) {
        for place in places {
            snapshot[place.id] = place
        }
    }
}
