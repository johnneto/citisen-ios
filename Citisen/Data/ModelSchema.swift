import Foundation
import os
import SwiftData

enum AppModelSchema {
    static let models: [any PersistentModel.Type] = [
        SavedSpotEntity.self,
        SavedPlace.self
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
        // No seed data required for the current schema.
    }
}
