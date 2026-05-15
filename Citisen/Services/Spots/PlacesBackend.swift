import Foundation

protocol PlacesBackend: AnyObject {
    func loadSpots(
        city: City,
        mode: TravelMode,
        viewport: Viewport?,
        forceRefresh: Bool
    ) async throws -> [Place]

    func search(query: String, city: City) async -> [Place]

    func resolvePlace(id: UUID) async -> Place?
}
