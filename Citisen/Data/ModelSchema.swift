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
        do {
            let schema = Schema(models)
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            let container = try ModelContainer(for: schema, configurations: [config])
            seedIfNeeded(container.mainContext)
            return container
        } catch {
            AppLog.data.fault("Failed to build ModelContainer: \(error.localizedDescription, privacy: .public)")
            // Fall back to in-memory so the app stays usable.
            // swiftlint:disable:next force_try
            return try! ModelContainer(
                for: Schema(models),
                configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
            )
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
