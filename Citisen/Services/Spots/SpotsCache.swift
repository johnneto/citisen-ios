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

final class SpotsCache {
    private let directory: URL
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

    // MARK: - URLs

    private func listURL(for key: String) -> URL {
        directory.appendingPathComponent("list_\(sanitize(key)).json")
    }

    private func placeURL(for id: UUID) -> URL {
        directory.appendingPathComponent("place_\(id.uuidString).json")
    }

    private func sanitize(_ key: String) -> String {
        key.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }
}
