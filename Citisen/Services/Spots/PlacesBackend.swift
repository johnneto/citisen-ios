import Foundation

protocol PlacesBackend: AnyObject {
    func loadSpots(
        city: City,
        mode: TravelMode,
        viewport: Viewport?,
        forceRefresh: Bool
    ) async throws -> [Place]

    /// Streams resolved `Place`s as they are produced. Backends that resolve via
    /// per-spot calls (e.g. Google Places) yield each as soon as it returns so the
    /// map can render incrementally. Cached or mock backends yield the full set
    /// at once and finish immediately.
    func streamSpots(
        city: City,
        mode: TravelMode,
        viewport: Viewport?,
        forceRefresh: Bool
    ) -> AsyncThrowingStream<Place, Error>

    func search(query: String, city: City) async -> [Place]

    func resolvePlace(id: UUID) async -> Place?

    func clearCache(forCityId cityId: String)

    /// Returns the most recently cached non-empty spot list for the given city + mode,
    /// ignoring viewport constraints. Used to restore the previous session's results
    /// on cold start. Returns nil when no valid cache entry exists.
    func cachedSpots(city: City, mode: TravelMode) -> [Place]?
}
