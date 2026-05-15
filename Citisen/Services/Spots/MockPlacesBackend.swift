import CoreLocation
import Foundation

final class MockPlacesBackend: PlacesBackend {
    func loadSpots(
        city: City,
        mode: TravelMode,
        viewport: Viewport?,
        forceRefresh: Bool
    ) async throws -> [Place] {
        let candidates = MockSeed.places(for: city, mode: mode)
        let origin = city.center.clLocation
        return candidates.sorted { lhs, rhs in
            lhs.distance(from: origin) < rhs.distance(from: origin)
        }
    }

    func search(query: String, city: City) async -> [Place] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return [] }
        return MockSeed.places(for: city).filter {
            $0.name.lowercased().contains(trimmed)
                || $0.category.lowercased().contains(trimmed)
                || $0.tags.contains(where: { $0.lowercased().contains(trimmed) })
        }
    }

    func resolvePlace(id: UUID) async -> Place? {
        MockSeed.allPlaces.first { $0.id == id }
    }
}
