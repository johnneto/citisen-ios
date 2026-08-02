import SwiftUI

struct SearchView: View {
    @Environment(PlacesService.self)
    private var places
    @Environment(UserPreferencesService.self)
    private var prefs
    @Environment(CityService.self)
    private var cityService
    @Environment(AppRouter.self)
    private var router
    @Environment(\.dismiss)
    private var dismiss

    @State private var viewModel: SearchViewModel?
    @State private var pendingCity: SearchSuggestion?
    @State private var openingPlaceId: String?
    @State private var isSwitchingCity: Bool = false
    @FocusState private var isFocused: Bool

    private static let tryTerms = ["Cafés", "Restaurants", "Museums", "Parks", "Viewpoints", "Bars"]

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Search")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                            .tint(BrandColor.sand)
                    }
                }
        }
        .overlay {
            if let pendingCity {
                CitySwitchConfirmCard(
                    cityName: pendingCity.primaryText,
                    currentCityName: cityService.activeCity.name,
                    isSwitching: isSwitchingCity,
                    onCancel: { self.pendingCity = nil },
                    onConfirm: { confirmCitySwitch(pendingCity) }
                )
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: pendingCity)
        .onAppear {
            if viewModel == nil {
                viewModel = SearchViewModel(
                    places: places,
                    prefs: prefs,
                    cityService: cityService
                )
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isFocused = true
            }
        }
    }

    @ViewBuilder private var content: some View {
        if let viewModel {
            VStack(spacing: 0) {
                searchField(viewModel)
                Divider().background(AppColor.dividerSoft)
                results(viewModel)
            }
        } else {
            ProgressView()
        }
    }

    @ViewBuilder
    private func results(_ vm: SearchViewModel) -> some View {
        if vm.isQueryEmpty {
            recents(vm)
        } else if vm.isLoading, !vm.hasResults {
            loadingState
        } else if let message = vm.errorMessage, !vm.hasResults {
            errorState(message)
        } else if !vm.hasResults {
            emptyState
        } else {
            resultList(vm)
        }
    }

    private func searchField(_ vm: SearchViewModel) -> some View {
        @Bindable var vm = vm
        return HStack(spacing: Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppColor.textSecondary)
            TextField("Search places or cities", text: $vm.query)
                .focused($isFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !vm.query.isEmpty {
                Button {
                    vm.clearQuery()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppColor.textTertiary)
                }
                .accessibilityLabel("Clear")
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 12)
        .background(AppColor.surfaceGrouped)
        .clipShape(Capsule())
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }

    // MARK: - Idle state

    private func recents(_ vm: SearchViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if !vm.recent.isEmpty {
                    recentsSection(vm)
                }
                trySection(vm)
            }
        }
    }

    private func recentsSection(_ vm: SearchViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Recent searches")
                    .font(.caption11Bold)
                    .tracking(0.8)
                    .foregroundStyle(AppColor.textSecondary)
                Spacer()
                Button("Clear") { vm.clearRecents() }
                    .font(.caption12)
                    .foregroundStyle(BrandColor.sand)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xs)

            ForEach(vm.recent, id: \.self) { term in
                Button {
                    vm.applyRecent(term)
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundStyle(AppColor.textTertiary)
                        Text(term)
                            .font(.subheadline15)
                            .foregroundStyle(AppColor.textPrimary)
                        Spacer()
                        Image(systemName: "arrow.up.left")
                            .font(.caption12)
                            .foregroundStyle(AppColor.textTertiary)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Divider().background(AppColor.dividerSoft).padding(.leading, Spacing.lg)
            }
        }
    }

    private func trySection(_ vm: SearchViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Try")
                .font(.caption11Bold)
                .tracking(0.8)
                .foregroundStyle(AppColor.textSecondary)
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.xs)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Self.tryTerms, id: \.self) { term in
                        Button {
                            vm.applyRecent(term)
                        } label: {
                            Text(term)
                                .font(.footnote13.weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(BrandColor.sandTint)
                                .foregroundStyle(BrandColor.sandDeep)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.pressableScale)
                    }
                }
                .padding(.horizontal, Spacing.lg)
            }
        }
    }

    // MARK: - Results

    private func resultList(_ vm: SearchViewModel) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if !vm.citySuggestions.isEmpty {
                    sectionHeader("Cities")
                    ForEach(vm.citySuggestions) { suggestion in
                        Button {
                            pendingCity = suggestion
                        } label: {
                            row(suggestion)
                        }
                        .buttonStyle(.plain)
                        Divider().background(AppColor.dividerSoft).padding(.leading, 76)
                    }
                }

                if !vm.placeSuggestions.isEmpty {
                    sectionHeader("Places")
                    ForEach(vm.placeSuggestions) { suggestion in
                        Button {
                            openPlace(suggestion, using: vm)
                        } label: {
                            row(suggestion)
                        }
                        .buttonStyle(.plain)
                        .disabled(openingPlaceId != nil)
                        Divider().background(AppColor.dividerSoft).padding(.leading, 76)
                    }
                }

                if vm.isLoading {
                    SearchInlineSpinner()
                }
            }
            .padding(.top, Spacing.xs)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption11Bold)
            .tracking(0.8)
            .foregroundStyle(AppColor.textSecondary)
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xs)
    }

    private func row(_ suggestion: SearchSuggestion) -> some View {
        SearchSuggestionRow(
            suggestion: suggestion,
            mode: prefs.activeMode,
            isResolving: openingPlaceId == suggestion.placeId
        )
    }

    // MARK: - Placeholder states

    private var loadingState: some View {
        VStack {
            Spacer()
            SearchInlineSpinner()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func errorState(_ message: String) -> some View {
        SearchPlaceholderState(
            symbol: "exclamationmark.triangle",
            symbolColor: AppColor.warning,
            title: nil,
            message: message
        )
    }

    private var emptyState: some View {
        SearchPlaceholderState(
            symbol: "magnifyingglass",
            symbolColor: AppColor.textTertiary,
            title: "No results found",
            message: "Try a different term, or search for a city to travel there."
        )
    }

    // MARK: - Actions

    private func openPlace(_ suggestion: SearchSuggestion, using vm: SearchViewModel) {
        guard openingPlaceId == nil else { return }
        openingPlaceId = suggestion.placeId
        Task { @MainActor in
            let place = await vm.openPlace(suggestion)
            openingPlaceId = nil
            guard let place else { return }
            router.openPOIFromSheet(place.id, in: [place.id])
        }
    }

    private func confirmCitySwitch(_ suggestion: SearchSuggestion) {
        guard let viewModel, !isSwitchingCity else { return }
        isSwitchingCity = true
        Task { @MainActor in
            let didSwitch = await viewModel.switchCity(to: suggestion)
            isSwitchingCity = false
            pendingCity = nil
            if didSwitch {
                router.dismissSheet()
            }
        }
    }
}
