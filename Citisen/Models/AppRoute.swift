import Foundation

enum SavedGroupFilter: Hashable {
    case country(name: String, flag: String)
    case city(cityId: String)
    case mode(TravelMode)

    var title: String {
        switch self {
        case .country(let name, _): return name
        case .city(let id): return City.all.first(where: { $0.id == id })?.name ?? id
        case .mode(let mode): return mode.displayName
        }
    }
}

enum AppRoute: Hashable {
    case profile
    case saved
    case collectionDetail(UUID)
    case savedGroupDetail(SavedGroupFilter)
    case about
    case privacy
}

enum AppSheet: Identifiable, Hashable {
    case search
    case citySwitcher
    case modePicker(slotIndex: Int)
    case newCollection
    case poi(placeId: UUID)

    var id: String {
        switch self {
        case .search: return "search"
        case .citySwitcher: return "city"
        case .modePicker(let idx): return "mode-\(idx)"
        case .newCollection: return "new-collection"
        case .poi(let id): return "poi-\(id.uuidString)"
        }
    }
}
