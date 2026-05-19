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
    @FocusState private var isFocused: Bool

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

                if viewModel.query.trimmingCharacters(in: .whitespaces).isEmpty {
                    recents(viewModel)
                } else if viewModel.results.isEmpty {
                    emptyState
                } else {
                    resultList(viewModel)
                }
            }
        } else {
            ProgressView()
        }
    }

    private func searchField(_ vm: SearchViewModel) -> some View {
        @Bindable var vm = vm
        return HStack(spacing: Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppColor.textSecondary)
            TextField("Search places, categories, tags", text: $vm.query)
                .focused($isFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: vm.query) { _, newValue in
                    vm.onQueryChange(newValue)
                }
                .onSubmit { vm.performSearch() }

            if !vm.query.isEmpty {
                Button {
                    vm.query = ""
                    vm.onQueryChange("")
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
                    ForEach(["Old Town", "Cafés", "Viewpoints", "Sauna", "Markets"], id: \.self) { term in
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

    private func resultList(_ vm: SearchViewModel) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(vm.results) { place in
                    Button {
                        let ids = vm.results.map(\.id)
                        router.dismissSheet()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            router.openPOI(place.id, in: ids)
                        }
                    } label: {
                        resultRow(place)
                    }
                    .buttonStyle(.plain)
                    Divider().background(AppColor.dividerSoft).padding(.leading, 76)
                }
            }
            .padding(.top, Spacing.xs)
        }
    }

    private func resultRow(_ place: Place) -> some View {
        HStack(spacing: Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(place.mode.tintColor)
                Image(systemName: place.mode.iconSymbol)
                    .foregroundStyle(place.mode.color)
                    .font(.system(size: 20, weight: .semibold))
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .font(.subheadline15.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(place.category)
                    Text("·").foregroundStyle(AppColor.textTertiary)
                    Text(place.budgetLabel)
                    Text("·").foregroundStyle(AppColor.textTertiary)
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(AppColor.warning)
                    Text(String(format: "%.1f", place.rating))
                }
                .font(.caption12)
                .foregroundStyle(AppColor.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption12)
                .foregroundStyle(AppColor.textTertiary)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.sm) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(AppColor.textTertiary)
            Text("No results found")
                .font(.headline17)
                .foregroundStyle(AppColor.textPrimary)
            Text("Try a different term or switch cities.")
                .font(.footnote13)
                .foregroundStyle(AppColor.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
