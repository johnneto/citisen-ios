import Foundation

enum AppRoute: Hashable {
    case profile
    case saved
    case about
    case privacy
}

enum AppSheet: Identifiable, Hashable {
    case search
    case citySwitcher
    case modePicker(slotIndex: Int)
    case poi(placeId: UUID)

    var id: String {
        switch self {
        case .search: return "search"
        case .citySwitcher: return "city"
        case .modePicker(let idx): return "mode-\(idx)"
        case .poi(let id): return "poi-\(id.uuidString)"
        }
    }
}
