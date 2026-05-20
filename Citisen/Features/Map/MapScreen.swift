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

    let viewModel: MapViewModel

    @State private var poiCameraTask: Task<Void, Never>?
    @State private var welcomeCity: City?
    @State private var headingTracker = MapHeadingTracker()

    var body: some View {
        ZStack {
            mapContent(viewModel)
            overlay(viewModel)
            if case .loading = viewModel.phase {
                MapLoadingOverlay(mode: prefs.activeMode)
                    .ignoresSafeArea()
                    .transition(.opacity)
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
        .animation(.easeInOut(duration: 0.2), value: viewModel.phase)
        .animation(.easeInOut(duration: 0.25), value: welcomeCity?.id)
        .onDisappear {
            poiCameraTask?.cancel()
            poiCameraTask = nil
        }
        .onChange(of: locationService.currentLocation?.latitude) { _, _ in
            viewModel.centerOnUserIfAvailable()
        }
        .onChange(of: cityService.citySelectionEpoch) { _, _ in
            handleCityChange()
        }
        .onChange(of: prefs.activeMode) { _, _ in
            viewModel.applyCacheOrIdle()
        }
        .onChange(of: router.recenterTrigger) { _, _ in
            guard let id = router.poiSelectedId,
                  let place = viewModel.placesService.place(id: id) else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                viewModel.cameraPosition = .region(MKCoordinateRegion(
                    center: place.coordinate.clLocation,
                    span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                ))
            }
        }
        .onChange(of: router.poiSelectedId) { _, newValue in
            // Debounce so that rapid mid-swipe selection changes coalesce into a single
            // camera animation after the swipe settles — prevents first-swipe stutter.
            poiCameraTask?.cancel()
            guard let newValue else { return }
            // Skip when MapScreen isn't the visible top of navigation or the POI
            // sheet isn't presenting — avoids offscreen camera work during a
            // back-pop from Saved while `poiSelectedId` is still set.
            guard router.path.isEmpty, router.presentedSheet == .poi else { return }
            poiCameraTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 120_000_000)
                if Task.isCancelled { return }
                guard router.presentedSheet == .poi,
                      router.poiSelectedId == newValue else { return }
                guard let place = viewModel.placesService.place(id: newValue) else { return }
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    viewModel.cameraPosition = .region(MKCoordinateRegion(
                        center: place.coordinate.clLocation,
                        span: viewModel.visibleRegion?.span ?? MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                    ))
                }
            }
        }
    }

    private func mapContent(_ vm: MapViewModel) -> some View {
        @Bindable var vm = vm
        let filtered = vm.filteredPlaces()
        let filteredIds = filtered.map(\.id)
        return Map(position: $vm.cameraPosition) {
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
                    Button {
                        #if canImport(UIKit)
                        UISelectionFeedbackGenerator().selectionChanged()
                        #endif
                        router.openPOI(place.id, in: filteredIds)
                    } label: {
                        MapPinView(mode: place.mode, isSelected: isCurrent(place))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("\(place.name), \(place.category)"))
                }
            }
        }
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
        .ignoresSafeArea()
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: prefs.activeMode)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: vm.activeSubFilters)
        .animation(.easeInOut(duration: 0.2), value: vm.phase)
    }

    private func isCurrent(_ place: Place) -> Bool {
        router.presentedSheet == .poi && router.poiSelectedId == place.id
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
                onTapHamburger: { router.openHamburger() },
                onTapCity: { router.present(.citySwitcher) },
                onTapSearch: { router.present(.search) },
                onTapAvatar: { router.push(.profile) }
            )
            .padding(.horizontal, 12)

            SubFilterBar(mode: prefs.activeMode, active: $vm.activeSubFilters)
        }
        .padding(.top, 8)
    }

    private func bottomSection(_ vm: MapViewModel) -> some View {
        VStack(spacing: Spacing.sm) {
            if case .streaming = vm.phase {
                StreamingSpotsPill(mode: prefs.activeMode)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            phaseBanner(vm)
                .animation(.easeInOut(duration: 0.25), value: vm.phase)
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
            .padding(.bottom, 24)
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
        let newCity = cityService.activeCity
        let shouldWelcome = newCity.id != prefs.lastSessionCityId
        viewModel.handleCityChange()
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

private struct NearMeFAB: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "location.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(BrandColor.sand)
                .frame(width: 52, height: 52)
                .background(AppColor.surfaceElevated)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(AppColor.divider, lineWidth: 0.5))
                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
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
            Button(action: onLoad) {
                Text("Load")
                    .font(.footnote13.weight(.semibold))
                    .foregroundStyle(BrandColor.sand)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Load suggestions")
        }
        .padding(.leading, 14)
        .padding(.trailing, 4)
        .padding(.vertical, 6)
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
