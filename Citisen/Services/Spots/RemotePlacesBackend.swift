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
        let key = cacheKey(cityId: city.id, mode: mode)

        if !forceRefresh,
           let cached = cache.loadEntry(key: key),
           !cached.places.isEmpty {
            AppLog.places.debug("SpotsCache hit for \(key, privacy: .public)")
            return cached.places
        }

        let range = mode.suggestionCountRange
        let curated = try await gemini.curatedSpots(
            city: city,
            mode: mode,
            minCount: range.min,
            maxCount: range.max
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

        cache.saveList(key: key, places: resolved, viewport: effectiveViewport)
        return resolved
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
                    try await self.runStream(
                        city: city,
                        mode: mode,
                        viewport: viewport,
                        forceRefresh: forceRefresh,
                        continuation: continuation
                    )
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func search(query: String, city: City) async -> [Place] {
        await mockFallback.search(query: query, city: city)
    }

    func resolvePlace(id: UUID) async -> Place? {
        if let cached = cache.loadPlace(id: id) { return cached }
        return await mockFallback.resolvePlace(id: id)
    }

    func clearCache(forCityId cityId: String) {
        cache.clearLists(forCityId: cityId)
    }

    func cachedSpots(city: City, mode: TravelMode) -> [Place]? {
        let key = cacheKey(cityId: city.id, mode: mode)
        guard let cached = cache.loadEntry(key: key), !cached.places.isEmpty else { return nil }
        return cached.places
    }

    // MARK: - Internals

    private func runStream(
        city: City,
        mode: TravelMode,
        viewport: Viewport?,
        forceRefresh: Bool,
        continuation: AsyncThrowingStream<Place, Error>.Continuation
    ) async throws {
        let effectiveViewport = viewport ?? defaultViewport(for: city)
        let key = cacheKey(cityId: city.id, mode: mode)

        if !forceRefresh,
           let cached = cache.loadEntry(key: key),
           !cached.places.isEmpty {
            AppLog.places.debug("SpotsCache hit for \(key, privacy: .public) (stream)")
            for place in cached.places {
                continuation.yield(place)
            }
            return
        }

        let range = mode.suggestionCountRange
        let curated = try await gemini.curatedSpots(
            city: city,
            mode: mode,
            minCount: range.min,
            maxCount: range.max
        )
        try Task.checkCancellation()

        guard !curated.isEmpty else {
            throw SpotsError.aiUnavailable("Gemini returned no spots.")
        }

        var resolved: [Place] = []
        try await withThrowingTaskGroup(of: Place?.self) { group in
            let concurrency = AppConfig.Spots.placesConcurrency
            var iterator = curated.makeIterator()
            var inFlight = 0

            for _ in 0..<concurrency {
                if let next = iterator.next() {
                    group.addTask { [self] in
                        try await self.resolveOne(next, city: city, mode: mode, viewport: effectiveViewport)
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
                        continuation.yield(place)
                    }
                    inFlight -= 1
                    if let next = iterator.next() {
                        group.addTask { [self] in
                            try await self.resolveOne(next, city: city, mode: mode, viewport: effectiveViewport)
                        }
                        inFlight += 1
                    }
                }
            }
        }

        if resolved.isEmpty {
            throw SpotsError.aiUnavailable("No spots could be resolved on Google Places.")
        }

        cache.saveList(key: key, places: resolved, viewport: effectiveViewport)
    }

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
            guard let details = try await places.searchText(query: query, near: viewport.center) else {
                AppLog.places.debug("No match for \(curated.name, privacy: .public)")
                return nil
            }
            try Task.checkCancellation()
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

    private func cacheKey(cityId: String, mode: TravelMode) -> String {
        "\(cityId)_\(mode.rawValue)"
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
