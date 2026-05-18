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
                    ForEach(Array(ids.enumerated()), id: \.element) { index, id in
                        POIPage(
                            placeId: id,
                            pageIndex: ids.count > 1 ? index : nil,
                            pageCount: ids.count > 1 ? ids.count : nil
                        )
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
        .presentationDetents(
            [.height(340), .height(600), .large],
            selection: $router.poiDetent
        )
        .presentationDragIndicator(.visible)
        .presentationBackground(AppColor.surfaceElevated)
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
    let pageIndex: Int?
    let pageCount: Int?

    init(placeId: UUID, pageIndex: Int?, pageCount: Int?) {
        self.placeId = placeId
        self.pageIndex = pageIndex
        self.pageCount = pageCount
        _savedQuery = Query(filter: #Predicate<SavedSpotEntity> { $0.placeId == placeId })
    }

    private var savedEntity: SavedSpotEntity? { savedQuery.first }

    var body: some View {
        Group {
            if let place = resolved {
                POISheetView(
                    place: place,
                    pageIndex: pageIndex,
                    pageCount: pageCount
                )
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
