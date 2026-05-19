import SwiftUI

struct POIFloatingPills: View {
    let currentIndex: Int
    let total: Int
    let onOpenList: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("\(currentIndex) / \(total) places")
                .font(.caption12.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(AppColor.surfaceGrouped, in: Capsule())
                .overlay(Capsule().strokeBorder(AppColor.divider, lineWidth: 0.5))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                .accessibilityLabel("Place \(currentIndex) of \(total)")

            Button(action: onOpenList) {
                HStack(spacing: 5) {
                    Image(systemName: "list.bullet")
                    Text("Open list")
                }
                .font(.caption12.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(BrandColor.sand, in: Capsule())
                .shadow(color: BrandColor.sand.opacity(0.4), radius: 6, x: 0, y: 2)
            }
            .buttonStyle(.pressableScale)
            .accessibilityLabel("Open list of places")
        }
    }
}
