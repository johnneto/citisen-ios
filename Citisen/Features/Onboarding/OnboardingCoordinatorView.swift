import SwiftUI
import os

struct OnboardingCoordinatorView: View {
    @Environment(UserPreferencesService.self) private var prefs
    @Environment(LocationService.self) private var location

    enum Step {
        case welcome, modes, locationPermission
    }

    @State private var step: Step = .welcome
    @State private var draftModes: [TravelMode] = [.food, .nature, .turbo, .history]
    @State private var showSignInAlert = false

    var body: some View {
        ZStack {
            AppColor.surfacePrimary.ignoresSafeArea()

            switch step {
            case .welcome:
                WelcomeScreen(
                    onGetStarted: {
                        draftModes = prefs.activeModes
                        withAnimation(.easeInOut(duration: 0.25)) { step = .modes }
                    },
                    onSignIn: { showSignInAlert = true }
                )
                .transition(.asymmetric(insertion: .opacity, removal: .opacity))

            case .modes:
                ModeSelectionScreen(
                    modes: $draftModes,
                    onContinue: {
                        prefs.activeModes = draftModes
                        withAnimation(.easeInOut(duration: 0.25)) { step = .locationPermission }
                    },
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.25)) { step = .welcome }
                    }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))

            case .locationPermission:
                LocationPermissionScreen(
                    onAllow: {
                        prefs.locationRequested = true
                        location.requestWhenInUse()
                        commitOnboarding()
                    },
                    onSkip: {
                        prefs.locationRequested = true
                        commitOnboarding()
                    }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .alert("Sign in coming soon", isPresented: $showSignInAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Google and Apple sign-in arrive in a future release. For now, tap Get Started to set up your travel DNA.")
        }
    }

    private func commitOnboarding() {
        AppLog.nav.info("onboarding complete — modes: \(prefs.activeModes.map(\.rawValue))")
        prefs.onboardingComplete = true
    }
}
