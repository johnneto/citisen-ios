import Foundation

enum AppRoute: Hashable {
    case profile
    case saved
    case collectionDetail(UUID)
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
