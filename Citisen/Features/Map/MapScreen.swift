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
        .animation(.easeInOut(duration: 0.2), value: viewModel?.phase)
        .animation(.easeInOut(duration: 0.25), value: welcomeCity?.id)
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
        .onChange(of: prefs.activeMode) { _, _ in
            viewModel?.applyCacheOrIdle()
        }
        .onChange(of: router.poiSelectedId) { _, newValue in
            // Debounce so that rapid mid-swipe selection changes coalesce into a single
            // camera animation after the swipe settles — prevents first-swipe stutter.
            poiCameraTask?.cancel()
            guard let newValue, let vm = viewModel else { return }
            poiCameraTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 120_000_000)
                if Task.isCancelled { return }
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
        return Map(position: $vm.cameraPosition) {
            UserAnnotation()
            ForEach(vm.filteredPlaces()) { place in
                Annotation(place.name, coordinate: place.coordinate.clLocation) {
                    Button {
                        #if canImport(UIKit)
                        UISelectionFeedbackGenerator().selectionChanged()
                        #endif
                        router.openPOI(place.id, in: vm.filteredPlaces().map(\.id))
                    } label: {
                        MapPinView(mode: place.mode, isSelected: isCurrent(place))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("\(place.name), \(place.category)"))
                }
            }
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            vm.visibleRegion = context.region
        }
        .mapControls {
            MapCompass()
            MapPitchToggle()
        }
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
        .padding(.top, 54) // below safe area
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

            LiquidGlassTabBar()
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

    @ViewBuilder
    private func phaseBanner(_ vm: MapViewModel) -> some View {
        switch vm.phase {
        case .error(let message):
            ErrorBanner(message: message) { vm.fetchSuggestions(forceRefresh: true) }
                .padding(.horizontal, Spacing.md)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        case .idleNeedsFetch:
            LoadSuggestionsCard(cityName: cityService.activeCity.name) {
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
    let onLoad: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "sparkles")
                .foregroundStyle(BrandColor.sand)
            VStack(alignment: .leading, spacing: 2) {
                Text("Discover \(cityName)")
                    .font(.subheadline15.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)
                Text("Tap to load curated suggestions.")
                    .font(.caption12)
                    .foregroundStyle(AppColor.textSecondary)
            }
            Spacer(minLength: 8)
            Button("Load", action: onLoad)
                .font(.footnote13.weight(.semibold))
                .tint(BrandColor.sand)
        }
        .padding(.horizontal, 14)
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
