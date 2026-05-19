import CryptoKit
import Foundation
import OSLog
import UIKit

/// Two-tier cache for Google Places (New) photo media.
///
/// Memory → disk → network, with per-key inflight coalescing so concurrent
/// requests (carousel + viewer) share a single download. Disk files live under
/// `Library/Caches/PlacePhotos/` keyed by `sha256(name|WxH)` so the API key
/// (which sits in the photo media URL) does not influence cache identity.
actor PlacePhotoCache {
    @MainActor static let shared = PlacePhotoCache(
        client: GooglePlacesClient(),
        log: AppLog.places,
        ttl: AppConfig.Spots.photoCacheTTLSeconds,
        diskCapBytes: AppConfig.Spots.photoCacheDiskCapBytes,
        memoryCapBytes: AppConfig.Spots.photoCacheMemoryCapBytes
    )

    private let client: GooglePlacesClient
    private let urlSession: URLSession
    private let fileManager: FileManager
    private let log: Logger
    private let ttl: TimeInterval
    private let diskCapBytes: Int

    private let memory: NSCache<NSString, UIImage>
    private let directory: URL
    private var inflight: [String: Task<UIImage?, Never>] = [:]

    init(
        client: GooglePlacesClient,
        log: Logger,
        ttl: TimeInterval,
        diskCapBytes: Int,
        memoryCapBytes: Int,
        urlSession: URLSession = .shared,
        fileManager: FileManager = .default
    ) {
        self.client = client
        self.urlSession = urlSession
        self.fileManager = fileManager
        self.log = log
        self.ttl = ttl
        self.diskCapBytes = diskCapBytes

        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = memoryCapBytes
        self.memory = cache

        self.directory = Self.cacheDirectory(using: fileManager)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    // MARK: - Public

    /// Returns a display-ready image for the given Places photo `name`. The
    /// pipeline is memory → disk (mtime-gated) → network. Returns `nil` only
    /// when both disk and network paths fail.
    func image(
        for photoName: String,
        maxWidthPx: Int,
        maxHeightPx: Int
    ) async -> UIImage? {
        let key = Self.cacheKey(name: photoName, width: maxWidthPx, height: maxHeightPx)
        if let cached = memory.object(forKey: key as NSString) {
            return cached
        }
        if let existing = inflight[key] {
            return await existing.value
        }

        let task = Task<UIImage?, Never> { [weak self] in
            guard let self else { return nil }
            return await self.loadAndStore(
                key: key,
                name: photoName,
                width: maxWidthPx,
                height: maxHeightPx
            )
        }
        inflight[key] = task
        let result = await task.value
        inflight[key] = nil
        return result
    }

    /// Removes files older than `ttl` and, if still over `diskCapBytes`,
    /// deletes oldest-mtime files until under the cap.
    nonisolated static func purgeExpired(
        ttl: TimeInterval,
        diskCapBytes: Int,
        fileManager: FileManager = .default
    ) {
        let directory = cacheDirectory(using: fileManager)
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .fileSizeKey]
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else { return }

        let now = Date()
        var survivors: [DiskEntry] = []

        for url in contents {
            guard let values = try? url.resourceValues(forKeys: keys) else {
                try? fileManager.removeItem(at: url)
                continue
            }
            let mtime = values.contentModificationDate ?? .distantPast
            if now.timeIntervalSince(mtime) > ttl {
                try? fileManager.removeItem(at: url)
                continue
            }
            survivors.append(DiskEntry(url: url, mtime: mtime, size: values.fileSize ?? 0))
        }

        let total = survivors.reduce(0) { $0 + $1.size }
        guard total > diskCapBytes else { return }

        var remaining = total
        for entry in survivors.sorted(by: { $0.mtime < $1.mtime }) {
            if remaining <= diskCapBytes { break }
            try? fileManager.removeItem(at: entry.url)
            remaining -= entry.size
        }
    }

    // MARK: - Internals

    private func loadAndStore(
        key: String,
        name: String,
        width: Int,
        height: Int
    ) async -> UIImage? {
        if let onDisk = readFromDisk(key: key) {
            memory.setObject(onDisk, forKey: key as NSString, cost: cost(of: onDisk))
            return onDisk
        }
        guard let url = await client.photoMediaURL(name: name, maxWidthPx: width, maxHeightPx: height) else {
            return nil
        }
        do {
            let (data, response) = try await urlSession.data(from: url)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                log.error("PlacePhotoCache HTTP \(http.statusCode, privacy: .public) for \(name, privacy: .public)")
                return nil
            }
            guard let raw = UIImage(data: data) else { return nil }
            let prepared = raw.preparingForDisplay() ?? raw
            memory.setObject(prepared, forKey: key as NSString, cost: cost(of: prepared))
            writeToDisk(data: data, key: key)
            return prepared
        } catch {
            log.error("PlacePhotoCache fetch failed for \(name, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func readFromDisk(key: String) -> UIImage? {
        let url = directory.appendingPathComponent("\(key).jpg")
        guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
              let mtime = values.contentModificationDate else {
            return nil
        }
        guard Date().timeIntervalSince(mtime) < ttl else {
            try? fileManager.removeItem(at: url)
            return nil
        }
        guard let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            return nil
        }
        return image.preparingForDisplay() ?? image
    }

    private func writeToDisk(data: Data, key: String) {
        let url = directory.appendingPathComponent("\(key).jpg")
        try? data.write(to: url, options: .atomic)
    }

    private func cost(of image: UIImage) -> Int {
        let size = image.size
        let scale = image.scale
        let pixels = Int(size.width * scale) * Int(size.height * scale)
        return max(pixels * 4, 1)
    }

    // MARK: - Static helpers

    static func cacheKey(name: String, width: Int, height: Int) -> String {
        let raw = "\(name)|\(width)x\(height)"
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func cacheDirectory(using fileManager: FileManager) -> URL {
        let caches = (try? fileManager.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return caches.appendingPathComponent("PlacePhotos", isDirectory: true)
    }
}

private struct DiskEntry {
    let url: URL
    let mtime: Date
    let size: Int
}
