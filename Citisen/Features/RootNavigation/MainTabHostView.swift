import SwiftUI

struct MainTabHostView: View {
    @Environment(AppRouter.self)
    private var router
    @Environment(UserPreferencesService.self)
    private var prefs
    @Environment(CityService.self)
    private var city
    @Environment(MockPlacesService.self)
    private var places

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            ZStack {
                MapScreen()
                    .ignoresSafeArea()

                if let toast = router.nearMeToast {
                    toastView(toast)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                HamburgerMenuView()
                    .zIndex(100)
            }
            .navigationDestination(for: AppRoute.self, destination: destination(for:))
        }
        .sheet(item: $router.presentedSheet) { sheet in
            sheetContent(sheet)
        }
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .profile:
            ProfileView()
        case .saved:
            SavedPlacesView()
        case .about:
            WebContentView(
                title: "About Citisen",
                url: URL(string: AppConfig.aboutURLString)
            )
        case .privacy:
            WebContentView(
                title: "Privacy Policy",
                url: URL(string: AppConfig.privacyURLString)
            )
        }
    }

    @ViewBuilder
    private func sheetContent(_ sheet: AppSheet) -> some View {
        switch sheet {
        case .search:
            SearchView()
        case .citySwitcher:
            CitySwitcherSheet()
                .presentationDetents([.height(360), .medium])
                .presentationDragIndicator(.visible)
        case .modePicker(let slotIndex):
            modePickerSheet(slotIndex: slotIndex)
        case .poi(let placeId):
            poiSheet(for: placeId)
        }
    }

    @ViewBuilder
    private func modePickerSheet(slotIndex: Int) -> some View {
        @Bindable var prefs = prefs
        ModePickerSheet(
            currentMode: prefs.activeModes[safe: slotIndex] ?? .food,
            excluded: Set(prefs.activeModes).subtracting([prefs.activeModes[safe: slotIndex] ?? .food])
        ) { picked in
            prefs.replaceSlot(slotIndex, with: picked)
            router.dismissSheet()
        } onCancel: {
            router.dismissSheet()
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func poiSheet(for placeId: UUID) -> some View {
        @Bindable var router = router
        if let place = places.place(id: placeId) {
            POISheetView(place: place)
                .presentationDetents(
                    [.height(340), .height(600), .large],
                    selection: $router.poiDetent
                )
                .presentationBackgroundInteraction(.enabled(upThrough: .height(600)))
                .presentationDragIndicator(.visible)
                .presentationBackground(AppColor.surfaceElevated)
        } else {
            VStack {
                Text("Place not found").font(.headline17)
            }
            .padding()
        }
    }

    private func toastView(_ text: String) -> some View {
        VStack {
            Text(text)
                .font(.callout16)
                .foregroundStyle(.white)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(.black.opacity(0.8))
                .clipShape(Capsule())
                .padding(.top, 100)
            Spacer()
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
