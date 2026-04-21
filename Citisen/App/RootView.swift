import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(UserPreferencesService.self) private var prefs

    var body: some View {
        Group {
            if prefs.onboardingComplete {
                MainTabHostView()
            } else {
                OnboardingCoordinatorView()
            }
        }
        .preferredColorScheme(prefs.appearance.colorScheme)
        .tint(BrandColor.sand)
        .animation(.easeInOut(duration: 0.3), value: prefs.onboardingComplete)
    }
}
