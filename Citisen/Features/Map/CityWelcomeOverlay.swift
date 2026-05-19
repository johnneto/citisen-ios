import SwiftUI

/// Full-screen welcome animation shown when the active city changes (either via
/// the switcher or by the user landing in a different city than last session).
/// Pulses the country flag emoji at center with a "Welcome to {city, country}"
/// caption. Auto-dismissed by the caller after ~2.2 s.
struct CityWelcomeOverlay: View {
    let city: City

    @State private var pulse: Bool = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: Spacing.lg) {
                Text("Welcome to")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(AppColor.textSecondary)

                Text(city.flagEmoji)
                    .font(.system(size: 140))
                    .scaleEffect(pulse ? 1.1 : 1.0)
                    .shadow(color: .black.opacity(0.18), radius: 22, x: 0, y: 8)
                    .animation(
                        .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                        value: pulse
                    )

                VStack(spacing: 4) {
                    Text(city.name)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(AppColor.textPrimary)
                        .multilineTextAlignment(.center)
                    Text(city.country)
                        .font(.title3.weight(.regular))
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
            .padding(.horizontal, Spacing.lg)
        }
        .onAppear { pulse = true }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Welcome to \(city.name), \(city.country)")
    }
}

#Preview {
    CityWelcomeOverlay(city: City(
        id: "preview",
        name: "Lisbon",
        country: "Portugal",
        emojiFlag: "🇵🇹",
        center: Coordinate(latitude: 38.7223, longitude: -9.1393),
        defaultSpanKm: 8,
        countryCode: "PT"
    ))
}
