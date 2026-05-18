import SwiftData
import SwiftUI

struct SavedCollectionsView: View {
    @Environment(AppRouter.self)
    private var router
    @Environment(\.dismiss)
    private var dismiss

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
            pinnedHeader

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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var pinnedHeader: some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppColor.textPrimary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")

                Image(systemName: "bookmark.fill")
                    .font(.title2)
                    .foregroundStyle(AppColor.textPrimary)
                Text("Saved")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(AppColor.textPrimary)
                Spacer()
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)

            groupingPicker
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.sm)
        }
        .background(AppColor.surfacePrimary)
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
                        let ids = allSpots.map(\.placeId)
                        router.dismissSheet()
                        router.openPOI(spot.placeId, in: ids)
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

    // MARK: - Category (Type) group list

    private var typeGroupList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(categoryGroups) { group in
                    Button {
                        router.push(.savedGroupDetail(.category(group.category)))
                    } label: {
                        SavedGroupRow(
                            leading: .categoryIcon(symbol: Self.iconSymbol(forCategory: group.category)),
                            title: group.category,
                            count: group.count
                        )
                    }
                    .buttonStyle(.plain)
                    Divider().background(AppColor.dividerSoft).padding(.leading, 68)
                }
            }
            .padding(.top, Spacing.sm)
        }
    }

    static func iconSymbol(forCategory category: String) -> String {
        let lower = category.lowercased()
        if lower.contains("restaurant") || lower.contains("food") { return "fork.knife" }
        if lower.contains("cafe") || lower.contains("coffee") || lower.contains("bakery") { return "cup.and.saucer.fill" }
        if lower.contains("bar") || lower.contains("pub") || lower.contains("night") { return "wineglass.fill" }
        if lower.contains("hotel") || lower.contains("lodging") { return "bed.double.fill" }
        if lower.contains("museum") || lower.contains("gallery") { return "building.columns.fill" }
        if lower.contains("park") || lower.contains("garden") { return "leaf.fill" }
        if lower.contains("landmark") || lower.contains("attraction") || lower.contains("monument") { return "star.fill" }
        if lower.contains("store") || lower.contains("shop") || lower.contains("market") { return "bag.fill" }
        if lower.contains("church") || lower.contains("cathedral") || lower.contains("place of worship") { return "building.2.fill" }
        if lower.contains("beach") { return "beach.umbrella.fill" }
        return "mappin.circle.fill"
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

    private struct CategoryGroup: Identifiable {
        let category: String
        let count: Int
        let lastSavedAt: Date
        var id: String { category }
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

    private var categoryGroups: [CategoryGroup] {
        var counts: [String: Int] = [:]
        var latestDates: [String: Date] = [:]
        for spot in allSpots {
            let category = spot.placeCategory.isEmpty ? "Other" : spot.placeCategory
            counts[category, default: 0] += 1
            if let existing = latestDates[category] {
                if spot.savedAt > existing { latestDates[category] = spot.savedAt }
            } else {
                latestDates[category] = spot.savedAt
            }
        }
        return counts.keys.map { category in
            CategoryGroup(
                category: category,
                count: counts[category] ?? 0,
                lastSavedAt: latestDates[category] ?? .distantPast
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
        case categoryIcon(symbol: String)
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
        case .categoryIcon(let symbol):
            ZStack {
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(AppColor.surfaceGrouped)
                Image(systemName: symbol)
                    .foregroundStyle(AppColor.textPrimary)
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
