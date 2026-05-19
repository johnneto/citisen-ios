import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(UserPreferencesService.self)
    private var prefs

    @State private var showSplash: Bool = true

    var body: some View {
        ZStack {
            Group {
                if prefs.onboardingComplete {
                    MainTabHostView()
                } else {
                    OnboardingCoordinatorView()
                }
            }
            .animation(.easeInOut(duration: 0.3), value: prefs.onboardingComplete)

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1000)
            }
        }
        .preferredColorScheme(prefs.appearance.colorScheme)
        .tint(BrandColor.sand)
        .task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            withAnimation(.easeInOut(duration: 0.35)) {
                showSplash = false
            }
        }
    }
}
