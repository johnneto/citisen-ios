import Foundation
import Observation

@Observable
final class CityService {
    let cities: [City] = City.all
    private let prefs: UserPreferencesService

    init(prefs: UserPreferencesService) {
        self.prefs = prefs
    }

    var activeCity: City {
        cities.first(where: { $0.id == prefs.activeCityId }) ?? City.tallinn
    }

    func setActiveCity(_ city: City) {
        prefs.activeCityId = city.id
    }
}
