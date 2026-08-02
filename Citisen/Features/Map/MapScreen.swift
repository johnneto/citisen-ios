import MapKit
import SwiftUI

struct MapScreen: View {
    @Environment(UserPreferencesService.self)
    private var prefs
    @Environment(LocationService.self)
    private var locationService
    @Environment(CityService.self)
    private var cityService
    @Environment(PlacesService.self)
    private var places
    @Environment(AppRouter.self)
    private var router
    @Environment(\.openURL)
    private var openURL

    @State private var viewModel: MapViewModel?
    @State private var poiCameraTask: Task<Void, Never>?
    @State private var welcomeCity: City?
    @State private var headingTracker = MapHeadingTracker()

    var body: some View {
        ZStack {
            if let viewModel {
                mapContent(viewModel)
                overlay(viewModel)
                if case .loading = viewModel.phase {
                    MapLoadingOverlay(mode: prefs.activeMode)
                        .ignoresSafeArea()
                        .transition(.opacity)
                }
            } else {
                Color.clear
            }

            if let welcomeCity {
                CityWelcomeOverlay(city: welcomeCity)
                    .ignoresSafeArea()
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        // Opaque backdrop so the iOS 26 `glassEffect()` surfaces above
        // (top bar, banners, tab bar) sample a stable color while the
        // MapKit Metal layer reattaches on NavigationStack pop — otherwise
        // they momentarily render against the black window background.
        .background(AppColor.surfacePrimary.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.2), value: viewModel?.phase)
        .animation(.easeInOut(duration: 0.25), value: welcomeCity?.id)
        .onDisappear {
            poiCameraTask?.cancel()
            poiCameraTask = nil
        }
        .onAppear {
            if viewModel == nil {
                let vm = MapViewModel(
                    places: places,
                    prefs: prefs,
                    cityService: cityService,
                    locationService: locationService
                )
                viewModel = vm
                if locationService.authorizationStatus == .notDetermined {
                    locationService.requestWhenInUse()
                }
                locationService.startUpdating()
                if locationService.currentLocation != nil {
                    vm.centerOnUserIfAvailable()
                } else {
                    vm.loadInitial()
                }
            }
        }
        .onChange(of: locationService.currentLocation?.latitude) { _, _ in
            viewModel?.centerOnUserIfAvailable()
        }
        .onChange(of: cityService.citySelectionEpoch) { _, _ in
            handleCityChange()
        }
        .onChange(of: cityService.dynamicCity?.id) { _, _ in
            viewModel?.noteDynamicCityResolved()
        }
        .onChange(of: prefs.activeMode) { _, _ in
            viewModel?.applyCacheOrIdle()
        }
        .onChange(of: places.keptSpotIds) { _, _ in
            viewModel?.noteKeptSpotsChanged()
        }
        .onChange(of: router.recenterTrigger) { _, _ in
            guard let id = router.poiSelectedId,
                  let vm = viewModel,
                  let place = vm.placesService.place(id: id) else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                vm.cameraPosition = .region(MKCoordinateRegion(
                    center: place.coordinate.clLocation,
                    span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                ))
            }
        }
        .onChange(of: router.poiSelectedId) { _, newValue in
            // Debounce so that rapid mid-swipe selection changes coalesce into a single
            // camera animation after the swipe settles — prevents first-swipe stutter.
            poiCameraTask?.cancel()
            guard let newValue, let vm = viewModel else { return }
            // Skip when MapScreen isn't the visible top of navigation or the POI
            // sheet isn't presenting — avoids offscreen camera work during a
            // back-pop from Saved while `poiSelectedId` is still set.
            guard router.path.isEmpty, router.presentedSheet == .poi else { return }
            poiCameraTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 120_000_000)
                if Task.isCancelled { return }
                guard router.presentedSheet == .poi,
                      router.poiSelectedId == newValue else { return }
                guard let place = vm.placesService.place(id: newValue) else { return }
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    vm.cameraPosition = .region(MKCoordinateRegion(
                        center: place.coordinate.clLocation,
                        span: vm.visibleRegion?.span ?? MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                    ))
                }
            }
        }
    }

    private func mapContent(_ vm: MapViewModel) -> some View {
        @Bindable var vm = vm
        let filtered = vm.filteredPlaces
        let filteredIds = vm.filteredPlaceIds
        // The open place when it has no pin of its own — opened from search, or a
        // curated spot currently excluded by a sub-filter. Without this the camera
        // pans to a bare stretch of map while its sheet is up.
        let detached = detachedSelection(excluding: filteredIds)
        return MapReader { proxy in
            Map(position: $vm.cameraPosition) {
                if let userCoord = locationService.currentLocation {
                    Annotation("", coordinate: userCoord, anchor: .center) {
                        UserHeadingAnnotation(
                            locationService: locationService,
                            tracker: headingTracker
                        )
                    }
                    .annotationTitles(.hidden)
                }
                ForEach(filtered) { place in
                    Annotation(place.name, coordinate: place.coordinate.clLocation) {
                        pin(place, isSelected: isCurrent(place)) {
                            router.openPOI(place.id, in: filteredIds)
                        }
                    }
                }

                if let detached {
                    Annotation(detached.name, coordinate: detached.coordinate.clLocation) {
                        pin(detached, isSelected: true) {
                            router.requestPOIRecenter()
                        }
                    }
                }
            }
            // Pin taps are resolved by `MapPinHitTester` rather than by a Button
            // inside each annotation — see that type for why the buttons had to go.
            //
            // `simultaneousGesture` rather than `onTapGesture`: an exclusive tap
            // recognizer would claim the first tap of MapKit's own double-tap-to-
            // zoom and cancel it, trading one broken zoom gesture for another.
            .simultaneousGesture(
                SpatialTapGesture(coordinateSpace: .local).onEnded { value in
                    handleMapTap(
                        at: value.location,
                        hitTester: MapPinHitTester(proxy: proxy),
                        pins: filtered,
                        ids: filteredIds,
                        detached: detached
                    )
                }
            )
            .onMapCameraChange(frequency: .continuous) { context in
                // Both writes intentionally avoid the @Observable graph of the Map
                // content closure: `visibleRegion` is @ObservationIgnored, and the
                // tracker is only read inside `UserHeadingAnnotation.body`. Without
                // this isolation a 60 Hz camera stream re-diffed every pin and
                // flickered their shadows on tilt/move.
                vm.visibleRegion = context.region
                headingTracker.update(context.camera.heading)
            }
            .mapControls {
                MapCompass()
                MapPitchToggle()
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: prefs.activeMode)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: vm.activeSubFilters)
        .animation(.easeInOut(duration: 0.2), value: vm.phase)
    }

    @ViewBuilder
    private func overlay(_ vm: MapViewModel) -> some View {
        @Bindable var vm = vm

        VStack(spacing: 0) {
            topSection(vm)
            Spacer()
            bottomSection(vm)
        }
    }

    private func topSection(_ vm: MapViewModel) -> some View {
        @Bindable var vm = vm
        return VStack(spacing: Spacing.sm) {
            MapTopBar(
                cityName: cityService.activeCity.name,
                isCityPinned: cityService.isCityPinned,
                onTapHamburger: { router.openHamburger() },
                onTapCity: { router.present(.citySwitcher) },
                onTapSearch: { router.present(.search) },
                onTapAvatar: { router.push(.profile) }
            )
            .padding(.horizontal, 12)

            SubFilterBar(mode: prefs.activeMode, active: $vm.activeSubFilters)
        }
        .padding(.top, 54) // below safe area
    }

    private func bottomSection(_ vm: MapViewModel) -> some View {
        VStack(spacing: Spacing.sm) {
            if case .streaming = vm.phase {
                StreamingSpotsPill(mode: prefs.activeMode)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            bottomBanner(vm)
                .animation(.easeInOut(duration: 0.25), value: vm.phase)
                .animation(.easeInOut(duration: 0.25), value: vm.locationSuggestion?.id)
            HStack {
                Spacer()
                NearMeFAB {
                    if !vm.recenterOnUser() {
                        router.showToast("Enable location in Settings to use Near Me.")
                        vm.shouldShowLocationDeniedSettings = true
                    }
                }
                .padding(.trailing, Spacing.md)
            }

            TravelModeToolbar()
                .padding(.horizontal, 12)
                .padding(.bottom, 22)
        }
        .alert(
            "Location access needed",
            isPresented: Binding(
                get: { vm.shouldShowLocationDeniedSettings },
                set: { vm.shouldShowLocationDeniedSettings = $0 }
            )
        ) {
            Button("Open Settings") {
                #if canImport(UIKit)
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
                #endif
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Citisen needs location access to show nearby places. Enable it in Settings.")
        }
    }

    /// The "travel to where you actually are" offer takes the banner slot while
    /// it's up — it's a direct answer to a tap the user just made, so it outranks
    /// the ambient phase banner underneath.
    @ViewBuilder
    private func bottomBanner(_ vm: MapViewModel) -> some View {
        if let suggestion = vm.locationSuggestion {
            TravelToLocationCard(
                cityName: suggestion.name,
                pinnedCityName: cityService.activeCity.name,
                onTravel: { vm.acceptLocationSuggestion() },
                onDismiss: { vm.clearLocationSuggestion() }
            )
            .padding(.horizontal, Spacing.md)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            phaseBanner(vm)
        }
    }

    @ViewBuilder
    private func phaseBanner(_ vm: MapViewModel) -> some View {
        switch vm.phase {
        case .error(let message):
            ErrorBanner(message: message) { vm.fetchSuggestions(forceRefresh: true) }
                .padding(.horizontal, Spacing.md)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        case .idleNeedsFetch:
            LoadSuggestionsCard(cityName: cityService.activeCity.name, travelMode: prefs.activeMode.displayName) {
                vm.fetchSuggestions()
            }
            .padding(.horizontal, Spacing.md)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        case .loaded where vm.places.isEmpty:
            EmptyResultsCard { vm.fetchSuggestions(forceRefresh: true) }
                .padding(.horizontal, Spacing.md)
                .transition(.opacity)
        default:
            EmptyView()
        }
    }

    private func handleCityChange() {
        guard let vm = viewModel else { return }
        let newCity = cityService.activeCity
        let shouldWelcome = newCity.id != prefs.lastSessionCityId
        vm.handleCityChange()
        if shouldWelcome {
            showWelcome(for: newCity)
            prefs.lastSessionCityId = newCity.id
        }
    }

    private func showWelcome(for city: City) {
        welcomeCity = city
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            if welcomeCity?.id == city.id {
                welcomeCity = nil
            }
        }
    }
}

// MARK: - Pins and their taps

private extension MapScreen {
    /// A pin that is invisible to touch. `allowsHitTesting(false)` is what keeps
    /// the map's own pan/pinch/rotate recognizers whole; VoiceOver still reaches
    /// the pin because accessibility activation doesn't go through hit testing.
    func pin(_ place: Place, isSelected: Bool, action: @escaping () -> Void) -> some View {
        MapPinView(mode: place.mode, isSelected: isSelected)
            .allowsHitTesting(false)
            .accessibilityElement()
            .accessibilityLabel(Text("\(place.name), \(place.category)"))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default, action)
    }

    func handleMapTap(
        at point: CGPoint,
        hitTester: MapPinHitTester,
        pins: [Place],
        ids: [UUID],
        detached: Place?
    ) {
        // The detached pin is the one whose sheet is already open, so it wins any
        // overlap with a neighbouring curated pin.
        if let detached, hitTester.isHit(detached, at: point) {
            router.requestPOIRecenter()
            return
        }
        guard let place = hitTester.nearest(to: point, among: pins) else { return }
        #if canImport(UIKit)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
        router.openPOI(place.id, in: ids)
    }

    func isCurrent(_ place: Place) -> Bool {
        router.presentedSheet == .poi && router.poiSelectedId == place.id
    }

    /// The place whose sheet is open when it isn't among the rendered pins.
    func detachedSelection(excluding pinnedIds: [UUID]) -> Place? {
        guard router.presentedSheet == .poi,
              let selectedId = router.poiSelectedId,
              !pinnedIds.contains(selectedId) else { return nil }
        return places.place(id: selectedId)
    }
}

private struct NearMeFAB: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "location.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(BrandColor.sand)
                .frame(width: 52, height: 52)
                .liquidGlass(corner: 26, strength: .regular, interactive: true)
        }
        .buttonStyle(.pressableScale)
        .accessibilityLabel("Center on my location")
    }
}

private struct LoadSuggestionsCard: View {
    let cityName: String
    let travelMode: String
    let onLoad: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "sparkles")
                .foregroundStyle(BrandColor.sand)
            VStack(alignment: .leading, spacing: 2) {
                Text("Discover \(cityName)")
                    .font(.subheadline15.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)
                Text("Tap to load AI suggestions using \(travelMode) travel mode.")
                    .font(.caption12)
                    .foregroundStyle(AppColor.textSecondary)
            }
            Spacer(minLength: 6)
            Button("Load", action: onLoad)
                .font(.footnote13.weight(.semibold))
                .tint(BrandColor.sand)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .liquidGlass(corner: 16, strength: .regular, interactive: true)
    }
}

/// Offered after Near Me when the device is in a different city than the pinned
/// one. Accepting unpins, handing the trip back to the real location.
private struct TravelToLocationCard: View {
    let cityName: String
    let pinnedCityName: String
    let onTravel: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "location.circle.fill")
                .foregroundStyle(BrandColor.sand)
            VStack(alignment: .leading, spacing: 2) {
                Text("You're in \(cityName)")
                    .font(.subheadline15.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)
                Text("Travel here instead of \(pinnedCityName)?")
                    .font(.caption12)
                    .foregroundStyle(AppColor.textSecondary)
            }
            Spacer(minLength: 6)
            Button("Travel", action: onTravel)
                .font(.footnote13.weight(.semibold))
                .buttonStyle(.borderless)
                .tint(BrandColor.sand)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption12.weight(.semibold))
                    .foregroundStyle(AppColor.textTertiary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Keep \(pinnedCityName)")
        }
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .padding(.vertical, 12)
        .liquidGlass(corner: 16, strength: .regular, interactive: true)
    }
}

private struct StreamingSpotsPill: View {
    let mode: TravelMode

    var body: some View {
        LiquidGlassLoader(mode: mode, label: "Finding more spots…", size: 16)
            .accessibilityLabel("Finding more spots")
    }
}

private struct ErrorBanner: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppColor.warning)
            Text(message)
                .font(.footnote13)
                .foregroundStyle(AppColor.textPrimary)
                .lineLimit(2)
            Spacer(minLength: 8)
            Button("Retry", action: onRetry)
                .font(.footnote13.weight(.semibold))
                .tint(BrandColor.sand)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .liquidGlass(corner: 16, strength: .regular, interactive: false)
    }
}

private struct EmptyResultsCard: View {
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "mappin.slash")
                .foregroundStyle(AppColor.textTertiary)
            Text("No spots found here. Try a different mode or area.")
                .font(.footnote13)
                .foregroundStyle(AppColor.textPrimary)
                .lineLimit(2)
            Spacer(minLength: 8)
            Button("Retry", action: onRetry)
                .font(.footnote13.weight(.semibold))
                .tint(BrandColor.sand)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .liquidGlass(corner: 16, strength: .regular, interactive: false)
    }
}
