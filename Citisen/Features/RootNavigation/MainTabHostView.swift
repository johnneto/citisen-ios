import SwiftData
import SwiftUI

struct MainTabHostView: View {
    @Environment(AppRouter.self)
    private var router
    @Environment(UserPreferencesService.self)
    private var prefs
    @Environment(CityService.self)
    private var city
    @Environment(PlacesService.self)
    private var places

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            ZStack {
                MapScreen()

                if let toast = router.nearMeToast {
                    toastView(toast)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if router.presentedSheet == .poi,
                   router.poiDetent != .large,
                   router.poiPlaceIds.count > 1,
                   let selectedId = router.poiSelectedId,
                   let currentIndex = router.poiPlaceIds.firstIndex(of: selectedId) {
                    poiFloatingOverlay(
                        currentIndex: currentIndex + 1,
                        total: router.poiPlaceIds.count
                    )
                    .zIndex(50)
                }

                HamburgerMenuView()
                    .zIndex(100)
            }
            .background(AppColor.surfacePrimary.ignoresSafeArea())
            .navigationDestination(for: AppRoute.self, destination: destination(for:))
        }
        .sheet(item: $router.presentedSheet, onDismiss: { router.dismissSheet() }) { sheet in
            sheetContent(sheet)
        }
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .profile:
            ProfileView()
        case .saved:
            SavedCollectionsView()
        case .collectionDetail(let id):
            CollectionDetailView(collectionId: id)
        case .savedGroupDetail(let filter):
            SavedGroupDetailView(filter: filter)
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
        case .newCollection:
            NewCollectionSheet()
                .presentationDetents([.height(420)])
                .presentationDragIndicator(.visible)
        case .poi:
            poiPager()
        case .placesList:
            PlacesListView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
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

    /// Renders the floating pills outside the POI sheet so they sit above its
    /// top edge. Position is computed from the current detent — the sheet
    /// itself runs `presentationBackgroundInteraction(.enabled)` so the pills
    /// are tappable and the underlying map isn't dimmed.
    @ViewBuilder
    private func poiFloatingOverlay(currentIndex: Int, total: Int) -> some View {
        VStack {
            Spacer()
            POIFloatingPills(
                currentIndex: currentIndex,
                total: total,
                onOpenList: { router.openPlacesListFromPOI() }
            )
            .padding(.bottom, Self.sheetTopOffset(for: router.poiDetent))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.keyboard)
        .opacity(router.isPOISheetSettling ? 0 : 1)
        .animation(.easeInOut(duration: 0.18), value: router.isPOISheetSettling)
        .allowsHitTesting(!router.isPOISheetSettling)
    }

    private static func sheetTopOffset(for detent: PresentationDetent) -> CGFloat {
        // Visual offset from the bottom of the screen to *just above* the
        // sheet's top edge, in points. Tracks the fixed detent heights.
        if detent == .height(600) { return 600 + 8 }
        return 340 + 8
    }

    @ViewBuilder
    private func poiPager() -> some View {
        @Bindable var router = router
        let ids = router.poiPlaceIds

        // Paging ScrollView instead of TabView(.page): UIPageViewController rubber-bands
        // light/fast flicks back to the current page and loses the gesture mid-animation,
        // which the user perceives as the page freezing mid-swipe. `.scrollTargetBehavior(.paging)`
        // commits on translation, so any started drag always lands on a page.
        GeometryReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach(ids, id: \.self) { id in
                        POIPage(placeId: id)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .id(id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $router.poiSelectedId)
        }
        .ignoresSafeArea(.container, edges: .horizontal)
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onChange(of: proxy.size.height) { _, _ in
                        router.notePOISheetHeightChange()
                    }
            }
        )
        .presentationDetents(
            [.height(340), .height(600), .large],
            selection: $router.poiDetent
        )
        .presentationDragIndicator(.visible)
        .presentationBackground(AppColor.surfaceElevated)
        // Disables the dim layer and lets taps reach the floating pills overlay
        // rendered above the sheet's top edge in the parent ZStack.
        .presentationBackgroundInteraction(.enabled(upThrough: .height(600)))
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

/// Renders a single POI page inside the paging sheet. Resolves the place
/// asynchronously when it is not in the in-memory snapshot — e.g. after the
/// Gemini list cache expired but the saved entity still points at it — by
/// refetching through Google Places using the persisted `googlePlaceId`.
private struct POIPage: View {
    @Environment(PlacesService.self)
    private var places
    @Environment(AppRouter.self)
    private var router
    @Environment(\.modelContext)
    private var modelContext

    @Query private var savedQuery: [SavedSpotEntity]

    @State private var resolved: Place?
    @State private var notFound = false
    @State private var transientFailure = false

    let placeId: UUID

    init(placeId: UUID) {
        self.placeId = placeId
        _savedQuery = Query(filter: #Predicate<SavedSpotEntity> { $0.placeId == placeId })
    }

    private var savedEntity: SavedSpotEntity? { savedQuery.first }

    var body: some View {
        Group {
            if let place = resolved {
                POISheetView(place: place)
            } else if notFound {
                notFoundView
            } else if transientFailure {
                transientFailureView
            } else {
                loadingView
            }
        }
        .task(id: placeId) {
            await load()
        }
    }

    private var notFoundView: some View {
        VStack(spacing: Spacing.sm) {
            Text("Place not found")
                .font(.headline17)
                .foregroundStyle(AppColor.textPrimary)
            if savedEntity != nil {
                Button {
                    SavedSpotsService(context: modelContext).unsave(placeId: placeId)
                    router.dismissSheet()
                } label: {
                    Text("Remove")
                        .font(.subheadline15.weight(.semibold))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var transientFailureView: some View {
        VStack {
            Text("Place not found").font(.headline17)
        }
        .padding()
    }

    private var loadingView: some View {
        VStack {
            ProgressView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func load() async {
        if let snapshot = places.place(id: placeId) {
            resolved = snapshot
            return
        }
        let entity = savedEntity
        let result = await places.resolvePlaceResult(
            id: placeId,
            googlePlaceId: entity?.googlePlaceId,
            cityId: entity?.cityId,
            mode: entity?.mode
        )
        switch result {
        case .found(let place):
            resolved = place
        case .notFound:
            notFound = true
        case .transientFailure:
            transientFailure = true
        }
    }
}
