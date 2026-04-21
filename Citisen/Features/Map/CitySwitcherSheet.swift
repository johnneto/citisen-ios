import SwiftUI

struct CitySwitcherSheet: View {
    @Environment(CityService.self) private var cityService
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(cityService.cities) { city in
                        Button {
                            cityService.setActiveCity(city)
                            dismiss()
                        } label: {
                            HStack {
                                Text(city.emojiFlag)
                                    .font(.system(size: 22))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(city.name)
                                        .font(.headline17)
                                        .foregroundStyle(AppColor.textPrimary)
                                    Text(city.country)
                                        .font(.caption12)
                                        .foregroundStyle(AppColor.textSecondary)
                                }
                                Spacer()
                                if cityService.activeCity.id == city.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(BrandColor.sand)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Cities")
                }
            }
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
}
