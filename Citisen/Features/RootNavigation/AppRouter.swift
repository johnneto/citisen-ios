import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class AppRouter {
    var path: [AppRoute] = []
    var presentedSheet: AppSheet?
    var isHamburgerOpen: Bool = false
    var poiDetent: PresentationDetent = .height(340)
    var poiPlaceIds: [UUID] = []
    var poiSelectedId: UUID?
    var nearMeToast: String?
    var placesListAnchorId: UUID?
    var recenterTrigger: Int = 0
    /// True while the POI sheet's height is actively changing (mid-drag or
    /// mid-snap). Cleared after a short idle so the floating overlay can fade
    /// out during motion and fade back in once the sheet commits.
    var isPOISheetSettling: Bool = false
    /// Set to `true` while programmatically swapping `presentedSheet` between
    /// `.poi` and `.placesList`. `.sheet(item:)` fires `onDismiss` for both
    /// user-driven dismissal *and* identifier swaps; the flag tells
    /// `dismissSheet` to preserve POI pager state during a swap.
    private var isSwappingSheet: Bool = false
    private var settleTask: Task<Void, Never>?

    func push(_ route: AppRoute) {
        path.append(route)
    }

    func popToRoot() {
        path.removeAll()
    }

    func present(_ sheet: AppSheet) {
        presentedSheet = sheet
    }

    func dismissSheet() {
        if isSwappingSheet {
            isSwappingSheet = false
            return
        }
        if presentedSheet != nil { presentedSheet = nil }
        if !poiPlaceIds.isEmpty { poiPlaceIds = [] }
        if poiSelectedId != nil { poiSelectedId = nil }
        if placesListAnchorId != nil { placesListAnchorId = nil }
    }

    func openPlacesListFromPOI() {
        placesListAnchorId = poiSelectedId
        isSwappingSheet = true
        presentedSheet = .placesList
    }

    func selectPlaceFromList(_ placeId: UUID) {
        poiDetent = .height(340)
        poiSelectedId = placeId
        isSwappingSheet = true
        presentedSheet = .poi
    }

    func requestPOIRecenter() {
        recenterTrigger &+= 1
    }

    func notePOISheetHeightChange() {
        if !isPOISheetSettling { isPOISheetSettling = true }
        settleTask?.cancel()
        settleTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard let self, !Task.isCancelled else { return }
            self.isPOISheetSettling = false
        }
    }

    func openHamburger() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            isHamburgerOpen = true
        }
    }

    func closeHamburger() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            isHamburgerOpen = false
        }
    }

    func openPOI(_ placeId: UUID, in placeIds: [UUID]) {
        poiDetent = .height(340)
        let normalizedIds = placeIds.contains(placeId) ? placeIds : [placeId] + placeIds
        poiPlaceIds = normalizedIds
        poiSelectedId = placeId
        presentedSheet = .poi
    }

    func showToast(_ message: String) {
        nearMeToast = message
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                if self.nearMeToast == message { self.nearMeToast = nil }
            }
        }
    }
}
