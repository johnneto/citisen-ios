import CoreLocation
import Foundation
import SwiftData
import SwiftUI

enum GroupingCriterion: String, CaseIterable, Identifiable {
    case country = "Country"
    case city = "City"
    case placeType = "Place Type"
    case status = "Saved Status"

    var id: String { rawValue }
}

struct GroupedSection: Identifiable {
    let header: String
    let items: [SavedPlace]
    var id: String { header }
}

@MainActor
@Observable
final class SavedPlacesViewModel {
    var selectedGroupingCriterion: GroupingCriterion = .country
    var searchText: String = ""

    private var modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func groupedSections(from places: [SavedPlace]) -> [GroupedSection] {
        let filtered = places.filter { place in
            searchText.isEmpty
                || place.name.localizedStandardContains(searchText)
                || (place.city?.localizedStandardContains(searchText) ?? false)
                || (place.countryCode?.localizedStandardContains(searchText) ?? false)
        }

        let grouped: [String: [SavedPlace]]
        switch selectedGroupingCriterion {
        case .country:
            grouped = Dictionary(grouping: filtered) { $0.countryCode ?? "Unknown Country" }
        case .city:
            grouped = Dictionary(grouping: filtered) { $0.city ?? "Unknown City" }
        case .placeType:
            grouped = Dictionary(grouping: filtered) { $0.placeType.rawValue }
        case .status:
            grouped = Dictionary(grouping: filtered) { $0.status.rawValue }
        }

        return grouped
            .map { key, value in
                GroupedSection(
                    header: key,
                    items: value.sorted(using: KeyPathComparator(\.timestamp, order: .reverse))
                )
            }
            .sorted { lhs, rhs in
                if selectedGroupingCriterion == .country {
                    if lhs.header == "Unknown Country" { return false }
                    if rhs.header == "Unknown Country" { return true }
                }
                return lhs.header < rhs.header
            }
    }

    func savePlace(
        name: String,
        latitude: Double,
        longitude: Double,
        placeType: PlaceType,
        locationService: LocationService
    ) async {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        var countryCode: String?
        var city: String?

        do {
            (countryCode, city) = try await locationService.reverseGeocode(location: location)
        } catch {
            AppLog.location.error("Reverse geocoding failed: \(error.localizedDescription, privacy: .public)")
        }

        let place = SavedPlace(
            name: name,
            latitude: latitude,
            longitude: longitude,
            countryCode: countryCode,
            city: city,
            status: .wantToVisit,
            placeType: placeType
        )
        modelContext.insert(place)
        try? modelContext.save()
    }

    func updateStatus(of place: SavedPlace, to status: SavedPlaceStatus) {
        place.status = status
        try? modelContext.save()
    }

    func delete(_ place: SavedPlace) {
        modelContext.delete(place)
        try? modelContext.save()
    }
}
