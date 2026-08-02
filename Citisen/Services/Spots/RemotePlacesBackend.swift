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

    func resolvePlace(id: UUID) async -> Place? {
        if let cached = cache.loadPlace(id: id) { return cached }
        return await mockFallback.resolvePlace(id: id)
    }

    func resolvePlaceResult(
        id: UUID,
        googlePlaceId: String?,
        cityId: String?,
        mode: TravelMode?
    ) async -> PlaceResolution {
        if let cached = cache.loadPlace(id: id) { return .found(cached) }

        if let gpid = googlePlaceId, let cityId, let mode {
            do {
                guard let place = try await fetchAndCache(
                    googlePlaceId: gpid,
                    sessionToken: nil,
                    cityId: cityId,
                    mode: mode
                ) else {
                    return .notFound
                }
                return .found(place)
            } catch let spotsError as SpotsError {
                switch spotsError {
                case .placesNotFound:
                    return .notFound
                default:
                    AppLog.places.error("resolvePlaceResult failed for \(gpid, privacy: .public): \(spotsError.localizedDescription, privacy: .public)")
                    return .transientFailure
                }
            } catch {
                AppLog.places.error("resolvePlaceResult failed: \(error.localizedDescription, privacy: .public)")
                return .transientFailure
            }
        }

        if let mock = await mockFallback.resolvePlace(id: id) {
            return .found(mock)
        }
        return .notFound
    }

    func enrichPlace(_ place: Place) async -> Place? {
        guard place.detailsFetchedAt == nil, let googlePlaceId = place.googlePlaceId else {
            return nil
        }
        do {
            guard let details = try await places.placeDetails(id: googlePlaceId),
                  let fresh = PlaceMapper.makePlace(from: details, cityId: place.cityId, mode: place.mode) else {
                return nil
            }
            let merged = PlaceMapper.merge(fullDetails: fresh, preservingCuratedFrom: place)
            cache.savePlace(merged)
            return merged
        } catch {
            AppLog.places.error("enrichPlace failed for \(googlePlaceId, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func clearCache(forCityId cityId: String) {
        cache.clearLists(forCityId: cityId)
    }

    func cachedSpots(city: City, mode: TravelMode) -> [Place]? {
        let key = cacheKey(cityId: city.id, mode: mode)
        guard let cached = cache.loadEntry(key: key), !cached.places.isEmpty else { return nil }
        return cached.places
    }
}

// MARK: - Resolution internals

private extension RemotePlacesBackend {
    func runStream(
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

    func resolvePlaces(
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

    func resolveOne(
        _ curated: CuratedSpot,
        city: City,
        mode: TravelMode,
        viewport: Viewport
    ) async throws -> Place? {
        let query = "\(curated.name), \(city.name)"
        let typeHint = curated.primaryType?.trimmingCharacters(in: .whitespaces)
        let normalizedHint = (typeHint?.isEmpty == false) ? typeHint : nil
        // Bias over the whole viewport so outskirt suggestions aren't punished
        // (Places caps the circle at 50 km).
        let biasRadius = min(max(viewport.radiusKm * 1000, 5_000), 50_000)
        let context = PlaceResolutionScorer.Context(
            curatedName: curated.name,
            cityCenter: viewport.center,
            cityRadiusMeters: biasRadius
        )
        do {
            var candidates = try await places.searchTextCandidates(
                query: query,
                near: viewport.center,
                radius: biasRadius,
                includedType: normalizedHint
            )
            var choice = PlaceResolutionScorer.pickBest(candidates, context: context)
            // If the type-filtered search produced nothing usable, the Gemini hint
            // was likely wrong — retry without it so we still pick up the place.
            if choice == nil, normalizedHint != nil {
                AppLog.places.debug("No type-filtered match for \(curated.name, privacy: .public) (hint=\(normalizedHint ?? "-", privacy: .public)); retrying without includedType")
                candidates = try await places.searchTextCandidates(
                    query: query,
                    near: viewport.center,
                    radius: biasRadius
                )
                choice = PlaceResolutionScorer.pickBest(candidates, context: context)
            }
            guard let choice else {
                AppLog.places.debug("No match for \(curated.name, privacy: .public)")
                return nil
            }
            if choice.index != 0 {
                AppLog.places.info("Ranking override for \(curated.name, privacy: .public): picked #\(choice.index) '\(choice.place.displayName?.text ?? "-", privacy: .public)' score=\(String(format: "%.2f", choice.score), privacy: .public) nameSim=\(String(format: "%.2f", choice.nameSimilarity), privacy: .public) ratings=\(choice.place.userRatingCount ?? 0)")
            }
            try Task.checkCancellation()
            return PlaceMapper.makePlace(
                from: choice.place,
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

    func cacheKey(cityId: String, mode: TravelMode) -> String {
        "\(cityId)_\(mode.rawValue)"
    }

    func defaultViewport(for city: City) -> Viewport {
        let delta = city.defaultSpanKm / 111
        return Viewport(
            center: city.center.clLocation,
            latitudeDelta: delta,
            longitudeDelta: delta
        )
    }
}

// MARK: - Search resolution

extension RemotePlacesBackend {
    func resolveSearchResult(
        placeId: String,
        sessionToken: String?,
        cityId: String,
        mode: TravelMode
    ) async -> Place? {
        if let cached = cache.loadPlace(id: Place.id(forGooglePlaceId: placeId)) { return cached }
        do {
            return try await fetchAndCache(
                googlePlaceId: placeId,
                sessionToken: sessionToken,
                cityId: cityId,
                mode: mode
            )
        } catch {
            AppLog.places.error("resolveSearchResult failed for \(placeId, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Fetches details for a Google place id, maps it with the caller's `cityId`
    /// and `mode`, and writes it to the on-disk place cache. `sessionToken` binds
    /// the call to a preceding autocomplete session for billing.
    fileprivate func fetchAndCache(
        googlePlaceId: String,
        sessionToken: String?,
        cityId: String,
        mode: TravelMode
    ) async throws -> Place? {
        guard let details = try await places.placeDetails(id: googlePlaceId, sessionToken: sessionToken),
              let place = PlaceMapper.makePlace(from: details, cityId: cityId, mode: mode) else {
            return nil
        }
        cache.savePlace(place)
        return place
    }
}
