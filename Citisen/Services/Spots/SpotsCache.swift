import CoreLocation
import Foundation

struct CachedList: Codable {
    let cachedAt: Date
    let viewportCenter: Coordinate
    let viewportRadiusKm: Double
    let places: [Place]
}

struct CachedPlace: Codable {
    let cachedAt: Date
    let place: Place
}

/// Searched places the user explicitly chose to keep alongside the AI
/// suggestions for a city + mode. Deliberately has no `cachedAt`: unlike the
/// curated list these never expire, because the user picked them.
struct KeptPlaceList: Codable {
    let updatedAt: Date
    let places: [Place]
}

final class SpotsCache {
    private let directory: URL
    /// Kept places live outside `Caches`: everything else here is regenerable
    /// from Gemini + Google Places, but a spot the user deliberately kept is
    /// not, and iOS may purge `Caches` under storage pressure.
    private let keptDirectory: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let ttl: TimeInterval

    init(
        fileManager: FileManager = .default,
        ttl: TimeInterval = AppConfig.Spots.cacheTTLSeconds
    ) {
        self.fileManager = fileManager
        self.ttl = ttl
        let caches = (try? fileManager.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.directory = caches.appendingPathComponent("Spots", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let support = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? caches
        self.keptDirectory = support.appendingPathComponent("KeptSpots", isDirectory: true)
        try? fileManager.createDirectory(at: keptDirectory, withIntermediateDirectories: true)

        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        self.encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec
    }

    // MARK: - List

    func loadEntry(key: String) -> CachedList? {
        let url = listURL(for: key)
        guard let data = try? Data(contentsOf: url),
              let entry = try? decoder.decode(CachedList.self, from: data) else {
            return nil
        }
        guard Date().timeIntervalSince(entry.cachedAt) < ttl else {
            try? fileManager.removeItem(at: url)
            return nil
        }
        return entry
    }

    func saveList(key: String, places: [Place], viewport: Viewport) {
        guard !places.isEmpty else { return }
        let entry = CachedList(
            cachedAt: Date(),
            viewportCenter: Coordinate(
                latitude: viewport.center.latitude,
                longitude: viewport.center.longitude
            ),
            viewportRadiusKm: viewport.radiusKm,
            places: places
        )
        guard let data = try? encoder.encode(entry) else { return }
        try? data.write(to: listURL(for: key), options: .atomic)
    }

    // Individual `place_<uuid>.json` files are keyed by UUID and re-resolve cheaply, so we
    // intentionally only wipe per-city list caches here; orphans expire via TTL.
    func clearLists(forCityId cityId: String) {
        let prefix = "list_\(sanitize(cityId))_"
        let urls = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []
        for url in urls where url.lastPathComponent.hasPrefix(prefix) {
            try? fileManager.removeItem(at: url)
        }
    }

    // MARK: - Place

    func loadPlace(id: UUID) -> Place? {
        let url = placeURL(for: id)
        guard let data = try? Data(contentsOf: url),
              let entry = try? decoder.decode(CachedPlace.self, from: data) else {
            return nil
        }
        guard Date().timeIntervalSince(entry.cachedAt) < ttl else { return nil }
        return entry.place
    }

    func savePlace(_ place: Place) {
        let entry = CachedPlace(cachedAt: Date(), place: place)
        guard let data = try? encoder.encode(entry) else { return }
        try? data.write(to: placeURL(for: place.id), options: .atomic)
    }

    // MARK: - Kept places

    /// No TTL check — kept places outlive the curated list on purpose.
    func loadKeptPlaces(key: String) -> [Place] {
        guard let data = try? Data(contentsOf: keptURL(for: key)),
              let entry = try? decoder.decode(KeptPlaceList.self, from: data) else {
            return []
        }
        return entry.places
    }

    /// Appends `place`, replacing any earlier entry with the same id so a
    /// re-kept place keeps its position rather than duplicating. Oldest entries
    /// are dropped once the per-city+mode cap is exceeded.
    func appendKeptPlace(_ place: Place, key: String) {
        var places = loadKeptPlaces(key: key)
        if let existing = places.firstIndex(where: { $0.id == place.id }) {
            places[existing] = place
        } else {
            places.append(place)
        }
        let cap = AppConfig.Spots.maxKeptPlacesPerCityMode
        if places.count > cap {
            places.removeFirst(places.count - cap)
        }
        let entry = KeptPlaceList(updatedAt: Date(), places: places)
        guard let data = try? encoder.encode(entry) else { return }
        try? data.write(to: keptURL(for: key), options: .atomic)
    }

    // MARK: - URLs

    private func listURL(for key: String) -> URL {
        directory.appendingPathComponent("list_\(sanitize(key)).json")
    }

    private func keptURL(for key: String) -> URL {
        keptDirectory.appendingPathComponent("kept_\(sanitize(key)).json")
    }

    private func placeURL(for id: UUID) -> URL {
        directory.appendingPathComponent("place_\(id.uuidString).json")
    }

    private func sanitize(_ key: String) -> String {
        key.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }
}
