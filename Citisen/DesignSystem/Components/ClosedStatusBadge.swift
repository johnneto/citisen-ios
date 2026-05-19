import SwiftUI

struct ClosedStatusBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption11Bold)
            .foregroundStyle(AppColor.danger)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(AppColor.danger.opacity(0.12))
            .clipShape(Capsule())
            .accessibilityLabel(text)
    }
}
