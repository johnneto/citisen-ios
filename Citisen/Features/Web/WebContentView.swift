import SwiftUI

struct WebContentView: View {
    let title: String
    let url: URL?

    @Environment(\.openURL) private var openURL

    var body: some View {
        Group {
            if let url {
                SafariView(url: url)
                    .ignoresSafeArea()
            } else {
                unavailable
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var unavailable: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 36))
                .foregroundStyle(AppColor.textTertiary)
            Text("Unable to open page")
                .font(.headline17)
            Text("Check your internet connection and try again.")
                .font(.footnote13)
                .foregroundStyle(AppColor.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.surfacePrimary)
    }
}
