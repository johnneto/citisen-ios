import SwiftData
import SwiftUI

struct NewCollectionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(CityService.self) private var cityService
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var iconIndex: Int = 0
    @FocusState private var isFocused: Bool

    private let icons = [
        "bookmark.fill", "map.fill", "fork.knife", "leaf.fill",
        "camera.fill", "sparkles", "moon.stars.fill", "figure.walk"
    ]

    private let palettes: [[String]] = [
        ["C8975A", "D4695E", "4A8C6F"],
        ["5B6BF0", "B85CC8", "CF3E6E"],
        ["E08A3C", "4A8C6F", "5B6BF0"],
        ["7A5BCF", "CF3E6E", "D4695E"]
    ]
    @State private var paletteIndex: Int = 0

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                preview

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("NAME")
                        .font(.caption11Bold).tracking(0.8)
                        .foregroundStyle(AppColor.textSecondary)
                    TextField("e.g. Tallinn Favourites", text: $name)
                        .focused($isFocused)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, 12)
                        .background(AppColor.surfaceGrouped)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("ICON")
                        .font(.caption11Bold).tracking(0.8)
                        .foregroundStyle(AppColor.textSecondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(icons.indices, id: \.self) { idx in
                                Button {
                                    iconIndex = idx
                                } label: {
                                    Image(systemName: icons[idx])
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(iconIndex == idx ? .white : AppColor.textSecondary)
                                        .frame(width: 44, height: 44)
                                        .background(iconIndex == idx ? BrandColor.sand : AppColor.surfaceGrouped)
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.pressableScale)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("COLOUR")
                        .font(.caption11Bold).tracking(0.8)
                        .foregroundStyle(AppColor.textSecondary)
                    HStack(spacing: 10) {
                        ForEach(palettes.indices, id: \.self) { idx in
                            Button {
                                paletteIndex = idx
                            } label: {
                                paletteSwatch(palettes[idx])
                                    .overlay(
                                        Circle()
                                            .strokeBorder(paletteIndex == idx ? BrandColor.sand : .clear, lineWidth: 2)
                                    )
                            }
                            .buttonStyle(.pressableScale)
                        }
                    }
                }

                Spacer(minLength: 0)

                PrimaryButton(
                    title: "Create collection",
                    iconSymbol: "plus",
                    isEnabled: !trimmedName.isEmpty
                ) {
                    create()
                }
            }
            .padding(Spacing.lg)
            .navigationTitle("New collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.tint(BrandColor.sand)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { isFocused = true }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    private var preview: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                paletteSwatch(palettes[paletteIndex])
                    .frame(width: 64, height: 64)
                Image(systemName: icons[iconIndex])
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(trimmedName.isEmpty ? "New collection" : trimmedName)
                    .font(.headline17)
                    .foregroundStyle(AppColor.textPrimary)
                Text(cityService.activeCity.displayName)
                    .font(.footnote13)
                    .foregroundStyle(AppColor.textSecondary)
            }
            Spacer()
        }
        .padding(Spacing.md)
        .background(AppColor.surfaceElevated)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .strokeBorder(AppColor.divider, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }

    private func paletteSwatch(_ hexes: [String]) -> some View {
        ZStack {
            LinearGradient(
                colors: hexes.map { Color(hex: $0) },
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
    }

    private func create() {
        let service = SavedSpotsService(context: modelContext)
        _ = service.createCollection(
            name: trimmedName,
            city: cityService.activeCity,
            colorHexes: palettes[paletteIndex],
            iconSymbol: icons[iconIndex]
        )
        dismiss()
    }
}
