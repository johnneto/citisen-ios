import SwiftUI

struct Avatar: View {
    let initials: String
    var size: CGFloat = 36
    var tint: Color = BrandColor.sand

    var body: some View {
        ZStack {
            Circle().fill(tint.opacity(0.2))
            Text(initials)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
    }
}

struct DragHandle: View {
    var body: some View {
        Capsule()
            .fill(AppColor.divider)
            .frame(width: 36, height: 4)
            .padding(.vertical, 6)
            .accessibilityHidden(true)
    }
}

struct TagChip: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.caption12)
            .foregroundStyle(AppColor.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppColor.surfaceGrouped)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

struct RatingPill: View {
    let rating: SavedSpotRating
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: rating.iconSymbol)
                .foregroundStyle(rating.color)
                .font(.system(size: 18, weight: .semibold))
            Text(rating.label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppColor.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isSelected ? rating.color.opacity(0.12) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
