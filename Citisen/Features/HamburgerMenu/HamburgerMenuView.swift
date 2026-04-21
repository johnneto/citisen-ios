import SwiftUI

struct HamburgerMenuView: View {
    @Environment(AppRouter.self) private var router
    @Environment(UserPreferencesService.self) private var prefs
    @Environment(CityService.self) private var city
    @Environment(\.openURL) private var openURL

    @State private var showAbout = false
    @State private var showPrivacy = false
    @State private var showFeedbackAlert = false

    var body: some View {
        ZStack(alignment: .trailing) {
            if router.isHamburgerOpen {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { router.closeHamburger() }
                    .transition(.opacity)

                drawer
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: router.isHamburgerOpen)
        .sheet(isPresented: $showAbout) {
            if let url = URL(string: AppConfig.aboutURLString) {
                SafariView(url: url)
            }
        }
        .sheet(isPresented: $showPrivacy) {
            if let url = URL(string: AppConfig.privacyURLString) {
                SafariView(url: url)
            }
        }
        .alert("Feedback", isPresented: $showFeedbackAlert) {
            Button("Send email") {
                if let url = URL(string: "mailto:\(AppConfig.feedbackEmail)?subject=Citisen%20feedback") {
                    openURL(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Reach us at \(AppConfig.feedbackEmail).")
        }
    }

    private var drawer: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.top, 64)
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.lg)

            Divider().background(AppColor.dividerSoft).padding(.horizontal, Spacing.lg)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    row("magnifyingglass", "Search") {
                        router.closeHamburger()
                        router.present(.search)
                    }
                    row("bookmark", "Saved") {
                        router.closeHamburger()
                        router.push(.saved)
                    }
                    row("map", "Collections") {
                        router.closeHamburger()
                        router.push(.saved)
                    }
                    row("mappin.circle", "Change city") {
                        router.closeHamburger()
                        router.present(.citySwitcher)
                    }

                    Divider().background(AppColor.dividerSoft).padding(.vertical, 8).padding(.horizontal, Spacing.lg)

                    row("gearshape", "Preferences") {
                        router.closeHamburger()
                        router.push(.profile)
                    }
                    row("person.crop.circle", "Profile") {
                        router.closeHamburger()
                        router.push(.profile)
                    }
                    row("info.circle", "About Citisen") {
                        router.closeHamburger()
                        showAbout = true
                    }
                    row("lock.shield", "Privacy") {
                        router.closeHamburger()
                        showPrivacy = true
                    }
                    row("envelope", "Send feedback") {
                        router.closeHamburger()
                        showFeedbackAlert = true
                    }

                    Divider().background(AppColor.dividerSoft).padding(.vertical, 8).padding(.horizontal, Spacing.lg)

                    row("rectangle.portrait.and.arrow.right", "Sign out", muted: true) {
                        signOut()
                    }
                }
                .padding(.vertical, 4)
            }

            Spacer(minLength: 0)

            Text("Citisen v1.0")
                .font(.caption12)
                .foregroundStyle(AppColor.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 32)
        }
        .frame(width: 300)
        .background(AppColor.surfaceElevated)
        .clipShape(RoundedCorners(tl: 16, bl: 16))
        .overlay(
            Rectangle()
                .fill(AppColor.divider)
                .frame(width: 0.5)
                .frame(maxHeight: .infinity),
            alignment: .leading
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Avatar(initials: prefs.user.initials, size: 48)
            Text(prefs.user.displayName)
                .font(.headline17)
                .foregroundStyle(AppColor.textPrimary)
            Text(city.activeCity.displayName)
                .font(.footnote13)
                .foregroundStyle(AppColor.textSecondary)
        }
    }

    private func row(_ icon: String, _ label: String, muted: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(AppColor.textSecondary)
                    .frame(width: 24)
                Text(label)
                    .font(.system(size: 16))
                    .foregroundStyle(muted ? AppColor.textSecondary : AppColor.textPrimary)
                Spacer(minLength: 0)
                if !muted {
                    Image(systemName: "chevron.right")
                        .font(.caption12)
                        .foregroundStyle(AppColor.textTertiary)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func signOut() {
        router.closeHamburger()
        @Bindable var prefs = prefs
        prefs.onboardingComplete = false
        router.popToRoot()
    }
}

private struct RoundedCorners: Shape {
    var tl: CGFloat = 0
    var tr: CGFloat = 0
    var bl: CGFloat = 0
    var br: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        path.addArc(
            center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr),
            radius: tr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        path.addArc(
            center: CGPoint(x: rect.maxX - br, y: rect.maxY - br),
            radius: br, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        path.addArc(
            center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl),
            radius: bl, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        path.addArc(
            center: CGPoint(x: rect.minX + tl, y: rect.minY + tl),
            radius: tl, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false
        )
        path.closeSubpath()
        return path
    }
}
