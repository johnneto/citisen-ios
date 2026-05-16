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
        presentedSheet = nil
        poiPlaceIds = []
        poiSelectedId = nil
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
