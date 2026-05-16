import SwiftData
import SwiftUI

struct SavedCollectionsView: View {
    @Environment(AppRouter.self)
    private var router

    @Query(sort: \SavedSpotEntity.savedAt, order: .reverse)
    private var allSpots: [SavedSpotEntity]

    @State private var grouping: PlacesGrouping = .country

    enum PlacesGrouping: String, CaseIterable, Hashable {
        case country = "Country"
        case city = "City"
        case type = "Type"
        case all = "All"
    }

    var body: some View {
        VStack(spacing: 0) {
            groupingPicker
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.sm)

            if allSpots.isEmpty {
                emptySpotsState
            } else {
                switch grouping {
                case .country: countryGroupList
                case .city:    cityGroupList
                case .type:    typeGroupList
                case .all:     allSpotsList
                }
            }
        }
        .background(AppColor.surfacePrimary.ignoresSafeArea())
        .navigationTitle("Saved")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Grouping picker

    private var groupingPicker: some View {
        HStack(spacing: 0) {
            ForEach(PlacesGrouping.allCases, id: \.self) { option in
                groupingButton(option)
            }
        }
        .padding(4)
        .background(AppColor.surfaceGrouped)
        .clipShape(Capsule())
    }

    private func groupingButton(_ option: PlacesGrouping) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { grouping = option }
        } label: {
            Text(option.rawValue)
                .font(.subheadline15.weight(.semibold))
                .foregroundStyle(grouping == option ? AppColor.textPrimary : AppColor.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(grouping == option ? AppColor.surfaceElevated : .clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty state

    private var emptySpotsState: some View {
        VStack(spacing: Spacing.sm) {
            Spacer()
            Image(systemName: "star")
                .font(.system(size: 36))
                .foregroundStyle(AppColor.textTertiary)
            Text("No saved spots")
                .font(.headline17)
            Text("Tap Save on any place to rate it.")
                .font(.footnote13)
                .foregroundStyle(AppColor.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - All flat list

    private var allSpotsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(allSpots) { spot in
                    Button {
                        router.dismissSheet()
                        router.openPOI(spot.placeId)
                    } label: {
                        SavedSpotRow(spot: spot, showLocation: true)
                    }
                    .buttonStyle(.plain)
                    Divider().background(AppColor.dividerSoft).padding(.leading, 76)
                }
            }
            .padding(.top, Spacing.sm)
        }
    }

    // MARK: - Country group list

    private var countryGroupList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(countryGroups) { group in
                    Button {
                        router.push(.savedGroupDetail(.country(name: group.name, flag: group.flag)))
                    } label: {
                        SavedGroupRow(leading: .flag(group.flag), title: group.name, count: group.count)
                    }
                    .buttonStyle(.plain)
                    Divider().background(AppColor.dividerSoft).padding(.leading, 68)
                }
            }
            .padding(.top, Spacing.sm)
        }
    }

    // MARK: - City group list

    private var cityGroupList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(cityGroups) { group in
                    Button {
                        router.push(.savedGroupDetail(.city(cityId: group.cityId)))
                    } label: {
                        SavedGroupRow(leading: .flag(group.flag), title: group.cityName, count: group.count)
                    }
                    .buttonStyle(.plain)
                    Divider().background(AppColor.dividerSoft).padding(.leading, 68)
                }
            }
            .padding(.top, Spacing.sm)
        }
    }

    // MARK: - Mode (Type) group list

    private var typeGroupList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(modeGroups) { group in
                    Button {
                        router.push(.savedGroupDetail(.mode(group.mode)))
                    } label: {
                        SavedGroupRow(leading: .modeIcon(group.mode), title: group.mode.displayName, count: group.count)
                    }
                    .buttonStyle(.plain)
                    Divider().background(AppColor.dividerSoft).padding(.leading, 68)
                }
            }
            .padding(.top, Spacing.sm)
        }
    }

    // MARK: - Grouping computation

    private struct CountryGroup: Identifiable {
        let name: String
        let flag: String
        let count: Int
        let lastSavedAt: Date
        var id: String { name }
    }

    private struct CityGroup: Identifiable {
        let cityId: String
        let cityName: String
        let flag: String
        let count: Int
        let lastSavedAt: Date
        var id: String { cityId }
    }

    private struct ModeGroup: Identifiable {
        let mode: TravelMode
        let count: Int
        let lastSavedAt: Date
        var id: String { mode.rawValue }
    }

    private var countryGroups: [CountryGroup] {
        var counts: [String: Int] = [:]
        var flags: [String: String] = [:]
        var latestDates: [String: Date] = [:]
        for spot in allSpots {
            let country = spot.resolvedCountryName
            counts[country, default: 0] += 1
            if flags[country] == nil { flags[country] = spot.resolvedFlag }
            if let existing = latestDates[country] {
                if spot.savedAt > existing { latestDates[country] = spot.savedAt }
            } else {
                latestDates[country] = spot.savedAt
            }
        }
        return counts.keys.map { name in
            CountryGroup(
                name: name,
                flag: flags[name] ?? "",
                count: counts[name] ?? 0,
                lastSavedAt: latestDates[name] ?? .distantPast
            )
        }
        .sorted { $0.lastSavedAt > $1.lastSavedAt }
    }

    private var cityGroups: [CityGroup] {
        var counts: [String: Int] = [:]
        var cityNames: [String: String] = [:]
        var flags: [String: String] = [:]
        var latestDates: [String: Date] = [:]
        for spot in allSpots {
            let cid = spot.cityId
            counts[cid, default: 0] += 1
            if cityNames[cid] == nil { cityNames[cid] = spot.resolvedCityName }
            if flags[cid] == nil { flags[cid] = spot.resolvedFlag }
            if let existing = latestDates[cid] {
                if spot.savedAt > existing { latestDates[cid] = spot.savedAt }
            } else {
                latestDates[cid] = spot.savedAt
            }
        }
        return counts.keys.map { cityId in
            CityGroup(
                cityId: cityId,
                cityName: cityNames[cityId] ?? cityId,
                flag: flags[cityId] ?? "",
                count: counts[cityId] ?? 0,
                lastSavedAt: latestDates[cityId] ?? .distantPast
            )
        }
        .sorted { $0.lastSavedAt > $1.lastSavedAt }
    }

    private var modeGroups: [ModeGroup] {
        var counts: [TravelMode: Int] = [:]
        var latestDates: [TravelMode: Date] = [:]
        for spot in allSpots {
            let mode = spot.mode
            counts[mode, default: 0] += 1
            if let existing = latestDates[mode] {
                if spot.savedAt > existing { latestDates[mode] = spot.savedAt }
            } else {
                latestDates[mode] = spot.savedAt
            }
        }
        return counts.keys.map { mode in
            ModeGroup(
                mode: mode,
                count: counts[mode] ?? 0,
                lastSavedAt: latestDates[mode] ?? .distantPast
            )
        }
        .sorted { $0.lastSavedAt > $1.lastSavedAt }
    }
}

// MARK: - SavedGroupRow

struct SavedGroupRow: View {
    enum Leading {
        case flag(String)
        case modeIcon(TravelMode)
    }

    let leading: Leading
    let title: String
    let count: Int

    var body: some View {
        HStack(spacing: Spacing.md) {
            leadingView
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline15.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)
                Text("\(count) spot\(count == 1 ? "" : "s")")
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

    @ViewBuilder private var leadingView: some View {
        switch leading {
        case .flag(let emoji):
            Text(emoji.isEmpty ? "🌍" : emoji)
                .font(.system(size: 32))
                .frame(width: 44, height: 44)
        case .modeIcon(let mode):
            ZStack {
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(mode.tintColor)
                Image(systemName: mode.iconSymbol)
                    .foregroundStyle(mode.color)
                    .font(.system(size: 20, weight: .semibold))
            }
        }
    }
}

// MARK: - SavedSpotRow

struct SavedSpotRow: View {
    let spot: SavedSpotEntity
    var showLocation: Bool = false

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(spot.mode.tintColor)
                Image(systemName: spot.mode.iconSymbol)
                    .foregroundStyle(spot.mode.color)
                    .font(.system(size: 20, weight: .semibold))
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 2) {
                if showLocation {
                    HStack(spacing: 4) {
                        Text(spot.placeName)
                            .font(.subheadline15.weight(.semibold))
                            .foregroundStyle(AppColor.textPrimary)
                            .lineLimit(1)
                            .layoutPriority(0)
                        Text("\(spot.resolvedCityName), \(spot.resolvedCountryName)")
                            .font(.caption12)
                            .foregroundStyle(AppColor.textSecondary)
                            .lineLimit(1)
                            .layoutPriority(1)
                    }
                } else {
                    Text(spot.placeName)
                        .font(.subheadline15.weight(.semibold))
                        .foregroundStyle(AppColor.textPrimary)
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    Text(spot.placeCategory)
                    Text("·").foregroundStyle(AppColor.textTertiary)
                    Image(systemName: spot.rating.iconSymbol)
                        .font(.system(size: 10))
                        .foregroundStyle(spot.rating.color)
                    Text(spot.rating.label)
                        .foregroundStyle(spot.rating.color)
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
}
