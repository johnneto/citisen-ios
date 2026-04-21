import CoreLocation
import Foundation
import Observation

@Observable
final class MockPlacesService {
    func places(city: City, mode: TravelMode, subFilters: Set<SubFilter> = []) -> [Place] {
        let candidates = MockSeed.places(for: city, mode: mode)
        let filtered = candidates.filter { place in
            subFilters.allSatisfy { $0.matches(place) }
        }
        return filtered.sorted { lhs, rhs in
            let origin = city.center.clLocation
            return lhs.distance(from: origin) < rhs.distance(from: origin)
        }
    }

    func place(id: UUID) -> Place? {
        MockSeed.allPlaces.first { $0.id == id }
    }

    func search(query: String, city: City) -> [Place] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return [] }
        return MockSeed.places(for: city).filter {
            $0.name.lowercased().contains(trimmed)
                || $0.category.lowercased().contains(trimmed)
                || $0.tags.contains(where: { $0.lowercased().contains(trimmed) })
        }
    }
}
