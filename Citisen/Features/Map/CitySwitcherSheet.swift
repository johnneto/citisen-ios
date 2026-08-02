import SwiftUI

struct CitySwitcherSheet: View {
    @Environment(CityService.self)
    private var cityService
    @Environment(\.dismiss)
    private var dismiss

    @State private var search = CitySearchViewModel()

    var body: some View {
        NavigationStack {
            List {
                if search.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    if cityService.isCityPinned {
                        useMyLocationSection()
                    }
                    recentsSection()
                } else {
                    resultsSection()
                }
            }
            .listStyle(.insetGrouped)
            .searchable(
                text: $search.query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: Text("Search city or country")
            )
            .autocorrectionDisabled()
            .navigationTitle("Change city")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(BrandColor.sand)
                }
            }
        }
    }

    /// Only shown while a city is pinned — clears the pin so the reverse-geocoded
    /// city takes over again.
    private func useMyLocationSection() -> some View {
        Section {
            Button {
                cityService.unpinCity()
                dismiss()
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "location.fill")
                        .foregroundStyle(BrandColor.sand)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Use my location")
                            .font(.headline17)
                            .foregroundStyle(AppColor.textPrimary)
                        Text("Follow the city you're actually in")
                            .font(.caption12)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
        }
    }

    @ViewBuilder
    private func recentsSection() -> some View {
        if cityService.recentCities.isEmpty {
            Section {
                EmptyRecentsHint()
            }
        } else {
            Section("Recent") {
                ForEach(cityService.recentCities) { city in
                    Button {
                        cityService.setActiveCity(city)
                        dismiss()
                    } label: {
                        CityRow(
                            flag: city.flagEmoji,
                            name: city.name,
                            subtitle: city.country,
                            isActive: cityService.activeCity.id == city.id
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func resultsSection() -> some View {
        Section {
            if search.isLoading {
                HStack {
                    ProgressView()
                    Text("Searching…")
                        .font(.footnote13)
                        .foregroundStyle(AppColor.textSecondary)
                }
            } else if let message = search.errorMessage {
                Text(message)
                    .font(.footnote13)
                    .foregroundStyle(AppColor.warning)
            } else if search.predictions.isEmpty {
                Text("No matches.")
                    .font(.footnote13)
                    .foregroundStyle(AppColor.textSecondary)
            } else {
                ForEach(search.predictions) { prediction in
                    Button {
                        Task { await select(prediction) }
                    } label: {
                        CityRow(
                            flag: "🔎",
                            name: prediction.primaryText,
                            subtitle: prediction.secondaryText,
                            isActive: false
                        )
                    }
                }
            }
        } header: {
            Text("Results")
        }
    }

    private func select(_ prediction: CityPrediction) async {
        guard let city = await search.resolve(prediction) else { return }
        cityService.setActiveCity(city)
        search.clear()
        dismiss()
    }
}

private struct CityRow: View {
    let flag: String
    let name: String
    let subtitle: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Text(flag)
                .font(.system(size: 22))
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.headline17)
                    .foregroundStyle(AppColor.textPrimary)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption12)
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
            Spacer()
            if isActive {
                Image(systemName: "checkmark")
                    .foregroundStyle(BrandColor.sand)
            }
        }
        .contentShape(Rectangle())
    }
}

private struct EmptyRecentsHint: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No recent cities yet")
                .font(.headline17)
                .foregroundStyle(AppColor.textPrimary)
            Text("Search for a city above to get started.")
                .font(.footnote13)
                .foregroundStyle(AppColor.textSecondary)
        }
        .padding(.vertical, 8)
    }
}
