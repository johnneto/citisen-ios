import MapKit
import SwiftUI

struct MapScreen: View {
    @Environment(UserPreferencesService.self) private var prefs
    @Environment(LocationService.self) private var locationService
    @Environment(CityService.self) private var cityService
    @Environment(MockPlacesService.self) private var places
    @Environment(AppRouter.self) private var router
    @Environment(\.openURL) private var openURL

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
                viewModel = MapViewModel(
                    places: places,
                    prefs: prefs,
                    cityService: cityService,
                    locationService: locationService
                )
            }
        }
        .onChange(of: cityService.activeCity) { _, _ in
            viewModel?.recenterOnCity()
        }
        .onChange(of: prefs.activeMode) { _, _ in
            // Mode filter is derived in currentPlaces() — no state to sync,
            // but we want a nice spring animation for pin changes.
        }
    }

    private func mapContent(_ vm: MapViewModel) -> some View {
        @Bindable var vm = vm
        return Map(position: $vm.cameraPosition) {
            UserAnnotation()
            ForEach(vm.currentPlaces()) { place in
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
        }
        .mapControls {
            MapCompass()
            MapPitchToggle()
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: prefs.activeMode)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: vm.activeSubFilters)
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

            SubFilterBar(mode: prefs.activeMode, active: $vm.activeSubFilters)
        }
        .padding(.top, 54) // below safe area
    }

    private func bottomSection(_ vm: MapViewModel) -> some View {
        VStack(spacing: Spacing.sm) {
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
