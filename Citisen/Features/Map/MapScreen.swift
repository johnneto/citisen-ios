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

    var body: some View {
        ZStack {
            if let viewModel {
                mapContent(viewModel)
                overlay(viewModel)
            } else {
                Color.clear
            }
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
                vm.reload()
            }
        }
        .onChange(of: cityService.activeCity) { _, _ in
            viewModel?.recenterOnCity()
            viewModel?.reload()
        }
        .onChange(of: prefs.activeMode) { _, _ in
            viewModel?.reload()
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
                        router.openPOI(place.id)
                    } label: {
                        MapPinView(mode: place.mode, isSelected: isCurrent(place))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("\(place.name), \(place.category)"))
                }
            }
            if case .loading = vm.phase {
                ForEach(Array(skeletonAnchors(for: vm).enumerated()), id: \.offset) { _, coord in
                    Annotation("", coordinate: coord) {
                        SkeletonPinView()
                    }
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

    private func skeletonAnchors(for vm: MapViewModel) -> [CLLocationCoordinate2D] {
        let center = vm.visibleRegion?.center ?? cityService.activeCity.center.clLocation
        let span = vm.visibleRegion?.span.latitudeDelta ?? 0.05
        let radius = span * 0.35
        return (0..<6).map { i in
            let angle = Double(i) * (.pi * 2 / 6)
            return CLLocationCoordinate2D(
                latitude: center.latitude + cos(angle) * radius,
                longitude: center.longitude + sin(angle) * radius * 1.5
            )
        }
    }

    private func isCurrent(_ place: Place) -> Bool {
        if case .poi(let id) = router.presentedSheet, id == place.id { return true }
        return false
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

            if vm.shouldOfferSearchThisArea() {
                SearchThisAreaPill(
                    onSearch: { vm.reload(forceRefresh: false) },
                    onForceRefresh: { vm.reload(forceRefresh: true) }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            SubFilterBar(mode: prefs.activeMode, active: $vm.activeSubFilters)
        }
        .padding(.top, 54) // below safe area
        .animation(.easeInOut(duration: 0.2), value: vm.shouldOfferSearchThisArea())
    }

    private func bottomSection(_ vm: MapViewModel) -> some View {
        VStack(spacing: Spacing.sm) {
            phaseBanner(vm)
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
            ErrorBanner(message: message) { vm.reload(forceRefresh: true) }
                .padding(.horizontal, Spacing.md)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        case .loaded where vm.places.isEmpty:
            EmptyResultsCard { vm.reload(forceRefresh: true) }
                .padding(.horizontal, Spacing.md)
                .transition(.opacity)
        default:
            EmptyView()
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

private struct SkeletonPinView: View {
    @State private var pulse: Bool = false

    var body: some View {
        Circle()
            .fill(AppColor.surfaceElevated)
            .frame(width: 28, height: 28)
            .overlay(
                Circle()
                    .strokeBorder(AppColor.divider, lineWidth: 1)
            )
            .opacity(pulse ? 0.45 : 0.85)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever()) {
                    pulse = true
                }
            }
            .accessibilityHidden(true)
    }
}

private struct SearchThisAreaPill: View {
    let onSearch: () -> Void
    let onForceRefresh: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onSearch) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                    Text("Search this area")
                }
                .font(.subheadline15.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .buttonStyle(.pressableScale)

            Divider().frame(height: 18)

            Button(action: onForceRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColor.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.pressableScale)
            .accessibilityLabel("Force refresh")
        }
        .liquidGlass(corner: 22, strength: .regular, interactive: true)
        .padding(.horizontal, 12)
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
