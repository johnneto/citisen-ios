import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class POISheetViewModel {
    let place: Place
    var isSaveMenuOpen: Bool = false
    var currentRating: SavedSpotRating?
    var isHoursExpanded: Bool = false

    private let savedSpots: SavedSpotsService

    init(place: Place, context: ModelContext) {
        self.place = place
        self.savedSpots = SavedSpotsService(context: context)
        self.currentRating = savedSpots.savedRating(for: place.id)
    }

    func pick(_ rating: SavedSpotRating) {
        if currentRating == rating {
            savedSpots.unsave(placeId: place.id)
            currentRating = nil
        } else {
            savedSpots.setRating(rating, for: place)
            currentRating = rating
        }
        isSaveMenuOpen = false
    }

    func toggleSaveMenu() {
        isSaveMenuOpen.toggle()
    }
}
