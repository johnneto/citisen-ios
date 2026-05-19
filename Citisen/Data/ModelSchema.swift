import Foundation
import os
import SwiftData

enum AppModelSchema {
    static let models: [any PersistentModel.Type] = [
        SavedSpotEntity.self,
        CollectionEntity.self
    ]

    @MainActor
    static func makeContainer() -> ModelContainer {
        let schema = Schema(models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            seedIfNeeded(container.mainContext)
            return container
        } catch {
            // Persistent store creation failed — most likely an incompatible
            // schema after adding a non-optional property. Reset the on-disk
            // store and retry once so persistence still works going forward
            // (one-time data loss is preferable to silently dropping into an
            // in-memory store and losing data on every launch).
            AppLog.data.fault("ModelContainer init failed; resetting store and retrying: \(error.localizedDescription, privacy: .public)")
            deleteDefaultStoreFiles()
            do {
                let container = try ModelContainer(for: schema, configurations: [config])
                seedIfNeeded(container.mainContext)
                return container
            } catch {
                AppLog.data.fault("ModelContainer retry failed; falling back to in-memory: \(error.localizedDescription, privacy: .public)")
                // swiftlint:disable:next force_try
                return try! ModelContainer(
                    for: schema,
                    configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
                )
            }
        }
    }

    private static func deleteDefaultStoreFiles() {
        guard let appSupport = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else { return }
        for suffix in ["", "-shm", "-wal"] {
            let url = appSupport.appendingPathComponent("default.store\(suffix)")
            try? FileManager.default.removeItem(at: url)
        }
    }

    @MainActor
    private static func seedIfNeeded(_ context: ModelContext) {
        let descriptor = FetchDescriptor<CollectionEntity>()
        let existing = (try? context.fetchCount(descriptor)) ?? 0
        guard existing == 0 else { return }

        let seed = CollectionEntity(
            name: "Tallinn Favourites",
            cityId: City.tallinn.id,
            cityName: City.tallinn.name,
            countryName: City.tallinn.country,
            colorHexes: ["C8975A", "4A8C6F", "5B6BF0"],
            iconSymbol: "heart.fill"
        )
        context.insert(seed)
        try? context.save()
    }
}
