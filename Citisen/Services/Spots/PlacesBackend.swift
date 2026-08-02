import Foundation

enum PlaceResolution {
    case found(Place)
    case notFound
    case transientFailure
}

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

    /// Resolves a Google place id picked from search autocomplete into a full
    /// `Place`. `sessionToken` is the autocomplete session the suggestion came
    /// from, so the details call is billed inside that session. `cityId` and
    /// `mode` stamp the resulting `Place` for caching and pin styling.
    func resolveSearchResult(
        placeId: String,
        sessionToken: String?,
        cityId: String,
        mode: TravelMode
    ) async -> Place?

    func resolvePlace(id: UUID) async -> Place?

    /// Resolves a Place using the in-app caches first, then falling back to
    /// Google Places by `googlePlaceId` when provided. `cityId` and `mode` are
    /// used to map the refetched details into the app's `Place` representation
    /// (they come from the persisted saved entity).
    func resolvePlaceResult(
        id: UUID,
        googlePlaceId: String?,
        cityId: String?,
        mode: TravelMode?
    ) async -> PlaceResolution

    /// Fetches the full Place Details payload (reviews, editorial summary) for
    /// a place that was resolved with the cheaper search field mask, preserving
    /// its curated description and tags. Returns nil when the place is already
    /// enriched, has no Google id, or the fetch fails — callers keep the
    /// original place in that case.
    func enrichPlace(_ place: Place) async -> Place?

    func clearCache(forCityId cityId: String)

    /// Returns the most recently cached non-empty spot list for the given city + mode,
    /// ignoring viewport constraints. Used to restore the previous session's results
    /// on cold start. Returns nil when no valid cache entry exists.
    func cachedSpots(city: City, mode: TravelMode) -> [Place]?
}
