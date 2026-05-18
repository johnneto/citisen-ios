import Foundation

enum SavedGroupFilter: Hashable {
    case country(name: String, flag: String)
    case city(cityId: String)
    case category(String)

    var title: String {
        switch self {
        case .country(let name, _): return name
        case .city(let id): return City.all.first(where: { $0.id == id })?.name ?? id
        case .category(let category): return category
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
    case poi

    var id: String {
        switch self {
        case .search: return "search"
        case .citySwitcher: return "city"
        case .modePicker(let idx): return "mode-\(idx)"
        case .newCollection: return "new-collection"
        case .poi: return "poi"
        }
    }
}
