import CoreLocation
import Foundation
import OSLog

final class RemotePlacesBackend: PlacesBackend {
    private let gemini: GeminiClient
    private let places: GooglePlacesClient
    private let cache: SpotsCache
    private let mockFallback: MockPlacesBackend

    init(
        gemini: GeminiClient = GeminiClient(),
        places: GooglePlacesClient = GooglePlacesClient(),
        cache: SpotsCache = SpotsCache(),
        mockFallback: MockPlacesBackend = MockPlacesBackend()
    ) {
        self.gemini = gemini
        self.places = places
        self.cache = cache
        self.mockFallback = mockFallback
    }

    func loadSpots(
        city: City,
        mode: TravelMode,
        viewport: Viewport?,
        forceRefresh: Bool
    ) async throws -> [Place] {
        let effectiveViewport = viewport ?? defaultViewport(for: city)
        let key = cacheKey(cityId: city.id, mode: mode, zoomBand: effectiveViewport.zoomBand)

        if !forceRefresh, let cached = cache.loadList(key: key) {
            AppLog.places.debug("SpotsCache hit for \(key, privacy: .public)")
            return cached
        }

        let count = min(effectiveViewport.dynamicCount, AppConfig.Spots.maxSpotsPerRequest)
        let curated = try await gemini.curatedSpots(
            city: city,
            mode: mode,
            viewport: effectiveViewport,
            count: count
        )
        try Task.checkCancellation()

        guard !curated.isEmpty else {
            throw SpotsError.aiUnavailable("Gemini returned no spots.")
        }

        let resolved = try await resolvePlaces(
            curated: curated,
            city: city,
            mode: mode,
            viewport: effectiveViewport
        )
        try Task.checkCancellation()

        if resolved.isEmpty {
            throw SpotsError.aiUnavailable("No spots could be resolved on Google Places.")
        }

        cache.saveList(key: key, places: resolved)
        return resolved
    }

    func search(query: String, city: City) async -> [Place] {
        await mockFallback.search(query: query, city: city)
    }

    func resolvePlace(id: UUID) async -> Place? {
        if let cached = cache.loadPlace(id: id) { return cached }
        return await mockFallback.resolvePlace(id: id)
    }

    // MARK: - Internals

    private func resolvePlaces(
        curated: [CuratedSpot],
        city: City,
        mode: TravelMode,
        viewport: Viewport
    ) async throws -> [Place] {
        let concurrency = AppConfig.Spots.placesConcurrency
        var resolved: [Place] = []

        try await withThrowingTaskGroup(of: Place?.self) { group in
            var iterator = curated.makeIterator()
            var inFlight = 0

            for _ in 0..<concurrency {
                if let next = iterator.next() {
                    group.addTask { [self] in
                        try await self.resolveOne(next, city: city, mode: mode, viewport: viewport)
                    }
                    inFlight += 1
                }
            }

            while inFlight > 0 {
                try Task.checkCancellation()
                if let place = try await group.next() {
                    if let place {
                        resolved.append(place)
                        cache.savePlace(place)
                    }
                    inFlight -= 1
                    if let next = iterator.next() {
                        group.addTask { [self] in
                            try await self.resolveOne(next, city: city, mode: mode, viewport: viewport)
                        }
                        inFlight += 1
                    }
                }
            }
        }

        return resolved
    }

    private func resolveOne(
        _ curated: CuratedSpot,
        city: City,
        mode: TravelMode,
        viewport: Viewport
    ) async throws -> Place? {
        let query = "\(curated.name), \(city.name)"
        do {
            guard let placeId = try await places.findPlaceId(text: query, near: viewport.center) else {
                AppLog.places.debug("ZERO_RESULTS for \(curated.name, privacy: .public)")
                return nil
            }
            try Task.checkCancellation()
            guard let details = try await places.placeDetails(placeId: placeId) else {
                return nil
            }
            return PlaceMapper.makePlace(
                from: details,
                curated: curated,
                city: city,
                mode: mode
            )
        } catch let spotsError as SpotsError {
            switch spotsError {
            case .placesNotFound:
                return nil
            case .placesQuota, .placesUnauthorized:
                throw spotsError
            default:
                AppLog.places.error("Resolve failed for \(curated.name, privacy: .public): \(spotsError.localizedDescription, privacy: .public)")
                return nil
            }
        }
    }

    private func cacheKey(cityId: String, mode: TravelMode, zoomBand: Int) -> String {
        "\(cityId)_\(mode.rawValue)_z\(zoomBand)"
    }

    private func defaultViewport(for city: City) -> Viewport {
        let delta = city.defaultSpanKm / 111
        return Viewport(
            center: city.center.clLocation,
            latitudeDelta: delta,
            longitudeDelta: delta
        )
    }
}
