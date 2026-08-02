import Foundation

/// One-shot migration that rewrites the on-disk Spots cache from the legacy
/// hardcoded city ids (`tallinn`, `tartu`, `helsinki`, `riga`) to the new
/// `dyn_<slug>_<countrycode>` scheme used everywhere after the city-driven
/// curation refactor. Also rewrites the `activeCityId` / `lastSessionCityId`
/// preference values and seeds `recentCities` so users land back in their
/// previous city without an extra Gemini call.
@MainActor
enum CacheMigrator {
    static func runIfNeeded(prefs: UserPreferencesService) {
        runListCachePhotoBump(prefs: prefs)
        runDetailsV3Bump(prefs: prefs)
        guard !prefs.spotsCacheMigratedV2 else { return }
        defer { prefs.spotsCacheMigratedV2 = true }

        let legacy: [String: City] = [
            "tallinn": .tallinn,
            "tartu": .tartu,
            "helsinki": .helsinki,
            "riga": .riga
        ]

        let directory = spotsDirectory()
        let fileManager = FileManager.default
        let listURLs = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ))?.filter { $0.lastPathComponent.hasPrefix("list_") } ?? []

        // Track which legacy cities had a cache hit so we can seed recents.
        var seenLegacy: [String: Date] = [:] // legacy id → newest mtime

        for url in listURLs {
            let name = url.lastPathComponent
            // Expected shape: list_<key>.json where key is "<cityId>_<mode>".
            guard name.hasPrefix("list_"), name.hasSuffix(".json") else { continue }
            let inner = String(name.dropFirst("list_".count).dropLast(".json".count))
            guard let underscore = inner.firstIndex(of: "_") else { continue }
            let oldCityId = String(inner[..<underscore])
            let modePart = String(inner[inner.index(after: underscore)...])
            guard let target = legacy[oldCityId] else { continue }

            let newName = "list_\(target.id)_\(modePart).json"
            let dest = directory.appendingPathComponent(newName)
            renameOrReconcile(at: url, to: dest, fileManager: fileManager)

            if let mtime = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate {
                if let existing = seenLegacy[oldCityId] {
                    seenLegacy[oldCityId] = max(existing, mtime)
                } else {
                    seenLegacy[oldCityId] = mtime
                }
            } else {
                seenLegacy[oldCityId] = Date.distantPast
            }
        }

        // Rewrite preference ids so cold-start cache match keeps working.
        if let mapped = legacy[prefs.activeCityId] {
            prefs.activeCityId = mapped.id
        }
        if let oldSession = prefs.lastSessionCityId, let mapped = legacy[oldSession] {
            prefs.lastSessionCityId = mapped.id
        }

        // Seed recentCities most-recent first, preserving the migrated ordering.
        let seededCities = seenLegacy
            .sorted { $0.value > $1.value }
            .compactMap { legacy[$0.key] }
        if !seededCities.isEmpty {
            var existing = prefs.recentCities
            for city in seededCities.reversed() {
                existing.removeAll { $0.id == city.id }
                existing.insert(city, at: 0)
            }
            if existing.count > UserPreferencesService.maxRecentCities {
                existing = Array(existing.prefix(UserPreferencesService.maxRecentCities))
            }
            prefs.recentCities = existing
        }
    }

    /// One-shot wipe of cached spot lists so users pick up the bumped 10-photo
    /// cap immediately instead of waiting out the 30-day TTL on pre-bump lists.
    /// Individual `place_<uuid>.json` files are left alone — they re-resolve
    /// cheaply and don't influence carousel pagination.
    private static func runListCachePhotoBump(prefs: UserPreferencesService) {
        guard !prefs.spotsListCacheClearedForPhotos10 else { return }
        defer { prefs.spotsListCacheClearedForPhotos10 = true }

        let directory = spotsDirectory()
        let fileManager = FileManager.default
        let contents = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []
        for url in contents where url.lastPathComponent.hasPrefix("list_") {
            try? fileManager.removeItem(at: url)
        }
    }

    /// One-shot wipe of both `list_*` and `place_*` caches after the details
    /// pipeline rework: cached places written before it lack structured opening
    /// periods and `utcOffsetMinutes`, so they would show "hours unknown" for up
    /// to the 30-day TTL. Wiping forces an immediate re-resolve with the new mask.
    private static func runDetailsV3Bump(prefs: UserPreferencesService) {
        guard !prefs.spotsCacheClearedForDetailsV3 else { return }
        defer { prefs.spotsCacheClearedForDetailsV3 = true }

        let directory = spotsDirectory()
        let fileManager = FileManager.default
        let contents = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []
        for url in contents
        where url.lastPathComponent.hasPrefix("list_") || url.lastPathComponent.hasPrefix("place_") {
            try? fileManager.removeItem(at: url)
        }
    }

    private static func renameOrReconcile(at source: URL, to destination: URL, fileManager: FileManager) {
        if !fileManager.fileExists(atPath: destination.path) {
            try? fileManager.moveItem(at: source, to: destination)
            return
        }
        // Destination exists — keep whichever file was modified more recently and
        // remove the loser. Falls back to keeping destination on inability to read mtimes.
        let sourceDate = (try? source.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate ?? .distantPast
        let destDate = (try? destination.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate ?? .distantPast
        if sourceDate > destDate {
            try? fileManager.removeItem(at: destination)
            try? fileManager.moveItem(at: source, to: destination)
        } else {
            try? fileManager.removeItem(at: source)
        }
    }

    private static func spotsDirectory() -> URL {
        let caches = (try? FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return caches.appendingPathComponent("Spots", isDirectory: true)
    }
}
