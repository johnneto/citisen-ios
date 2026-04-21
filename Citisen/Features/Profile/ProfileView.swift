import SwiftUI

struct ProfileView: View {
    @Environment(UserPreferencesService.self)
    private var prefs
    @Environment(CityService.self)
    private var cityService
    @Environment(AppRouter.self)
    private var router
    @Environment(\.openURL)
    private var openURL

    @State private var showSignOutConfirm = false

    var body: some View {
        @Bindable var prefs = prefs

        Form {
            Section {
                HStack(spacing: Spacing.md) {
                    Avatar(initials: prefs.user.initials, size: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(prefs.user.displayName)
                            .font(.headline17)
                            .foregroundStyle(AppColor.textPrimary)
                        Text(prefs.user.email)
                            .font(.footnote13)
                            .foregroundStyle(AppColor.textSecondary)
                        Text(cityService.activeCity.displayName)
                            .font(.caption12)
                            .foregroundStyle(AppColor.textTertiary)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            }

            Section("Your modes") {
                ForEach(Array(prefs.activeModes.enumerated()), id: \.offset) { index, mode in
                    Button {
                        router.present(.modePicker(slotIndex: index))
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            ZStack {
                                Circle().fill(mode.tintColor)
                                Image(systemName: mode.iconSymbol)
                                    .foregroundStyle(mode.color)
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .frame(width: 28, height: 28)
                            Text(mode.displayName)
                                .foregroundStyle(AppColor.textPrimary)
                            Spacer()
                            Text("Slot \(index + 1)")
                                .font(.caption12)
                                .foregroundStyle(AppColor.textTertiary)
                            Image(systemName: "chevron.right")
                                .font(.caption12)
                                .foregroundStyle(AppColor.textTertiary)
                        }
                    }
                }
            }

            Section("Appearance") {
                Picker("Theme", selection: $prefs.appearance) {
                    ForEach(UserPreferencesService.AppearanceOverride.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
            }

            Section("Units") {
                Toggle(isOn: $prefs.metricUnits) {
                    Text("Metric (km / m)")
                }
                .tint(BrandColor.sand)
            }

            Section("Notifications") {
                Toggle(isOn: $prefs.notificationsEnabled) {
                    Text("Enable notifications")
                }
                .tint(BrandColor.sand)
            }

            Section("City") {
                Button {
                    router.present(.citySwitcher)
                } label: {
                    HStack {
                        Text(cityService.activeCity.emojiFlag)
                        Text(cityService.activeCity.name)
                            .foregroundStyle(AppColor.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption12)
                            .foregroundStyle(AppColor.textTertiary)
                    }
                }
            }

            Section("About") {
                Button {
                    router.push(.about)
                } label: {
                    Label("About Citisen", systemImage: "info.circle")
                        .foregroundStyle(AppColor.textPrimary)
                }
                Button {
                    router.push(.privacy)
                } label: {
                    Label("Privacy policy", systemImage: "lock.shield")
                        .foregroundStyle(AppColor.textPrimary)
                }
                Button {
                    if let url = URL(string: AppConfig.termsURLString) {
                        openURL(url)
                    }
                } label: {
                    Label("Terms of service", systemImage: "doc.text")
                        .foregroundStyle(AppColor.textPrimary)
                }
                Button {
                    if let url = URL(string: "mailto:\(AppConfig.feedbackEmail)?subject=Citisen%20feedback") {
                        openURL(url)
                    }
                } label: {
                    Label("Send feedback", systemImage: "envelope")
                        .foregroundStyle(AppColor.textPrimary)
                }
                HStack {
                    Text("Version")
                        .foregroundStyle(AppColor.textPrimary)
                    Spacer()
                    Text("1.0")
                        .foregroundStyle(AppColor.textSecondary)
                }
            }

            Section {
                Button(role: .destructive) {
                    showSignOutConfirm = true
                } label: {
                    Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .confirmationDialog(
            "Sign out of Citisen?",
            isPresented: $showSignOutConfirm,
            titleVisibility: .visible
        ) {
            Button("Sign out", role: .destructive) {
                prefs.onboardingComplete = false
                router.popToRoot()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
