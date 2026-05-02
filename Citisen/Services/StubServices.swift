import Foundation
import os

// TODO: Stage 5 — wire Claude/GPT API. See docs/ADRs/ADR-001-maps-and-places.md.
final class AISpotService {
    func curatedSpots(city: City, mode: TravelMode) async throws -> [String] {
        AppLog.ai.debug("AISpotService placeholder called: \(city.id)/\(mode.rawValue)")
        return []
    }
}

// TODO: Stage 5 — Google Places (findplacefromtext + place details).
final class PlacesService {
    func resolve(name: String, inCity city: City) async throws -> Place? {
        AppLog.places.debug("PlacesService placeholder called for: \(name)")
        return nil
    }
}

// TODO: Stage 5 — FileManager Caches directory, keyed by cityId_modeRaw.
final class CacheService {
    func load<T: Decodable>(_ type: T.Type, for key: String) -> T? { nil }
    func save<T: Encodable>(_ value: T, for key: String) {}
}

// TODO: Stage 7 — PostHog integration.
@Observable
final class AnalyticsService {
    func track(_ event: String, properties: [String: String] = [:]) {
        AppLog.analytics.debug("event: \(event, privacy: .public) \(properties)")
    }
}

// TODO: Stage 7 — Sentry integration.
final class CrashReportingService {
    func report(_ error: Error, message: String? = nil) {
        AppLog.analytics.error("crash-report: \(message ?? "", privacy: .public) \(error.localizedDescription)")
    }
}
