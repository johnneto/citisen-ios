import Foundation
import Observation
import SwiftData

struct CityInfo {
    let name: String
    let country: String
    let flag: String
}

@Observable
@MainActor
final class POISheetViewModel {
    let place: Place
    var isSaveMenuOpen: Bool = false
    var isHoursExpanded: Bool = false

    private let savedSpots: SavedSpotsService
    private let cityInfoProvider: () -> CityInfo?

    init(
        place: Place,
        context: ModelContext,
        cityInfoProvider: @escaping () -> CityInfo? = { nil }
    ) {
        self.place = place
        self.savedSpots = SavedSpotsService(context: context)
        self.cityInfoProvider = cityInfoProvider
    }

    func pick(_ rating: SavedSpotRating, currentRating: SavedSpotRating?) {
        if currentRating == rating {
            savedSpots.unsave(placeId: place.id)
        } else {
            let info = cityInfoProvider()
            savedSpots.setRating(
                rating,
                for: place,
                cityName: info?.name,
                countryName: info?.country,
                emojiFlag: info?.flag
            )
        }
        isSaveMenuOpen = false
    }

    func toggleSaveMenu() {
        isSaveMenuOpen.toggle()
    }
}
