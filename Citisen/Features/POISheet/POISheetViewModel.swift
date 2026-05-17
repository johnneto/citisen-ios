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
        self.currentRating = nil
    }

    /// Loads the persisted rating for this place. Kept separate from `init` so a
    /// prefetched neighbour page in `TabView(.page)` doesn't perform a SwiftData
    /// fetch on the main actor mid-swipe — callers should invoke this *after* the
    /// gesture has settled.
    func loadRating() {
        currentRating = savedSpots.savedRating(for: place.id)
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
