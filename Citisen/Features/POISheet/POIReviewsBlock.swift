import SwiftUI

struct POIReviewsBlock: View {
    let place: Place
    let onAddReview: () -> Void
    let onSeeAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Reviews")
                    .font(.headline17)
                    .foregroundStyle(AppColor.textPrimary)
                Spacer()
                Button(action: onAddReview) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Add review")
                    }
                    .font(.caption11Bold)
                    .foregroundStyle(place.mode.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(place.mode.tintColor)
                    .clipShape(Capsule())
                }
            }

            ForEach(place.reviews) { review in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Avatar(initials: String(review.authorName.prefix(1)), size: 28)
                        Text(review.authorName)
                            .font(.footnote13.weight(.semibold))
                            .foregroundStyle(AppColor.textPrimary)
                        Text("· \(review.daysAgo)d ago")
                            .font(.caption12)
                            .foregroundStyle(AppColor.textTertiary)
                        Spacer()
                        HStack(spacing: 1) {
                            ForEach(0..<5, id: \.self) { idx in
                                Image(systemName: idx < review.rating ? "star.fill" : "star")
                                    .font(.system(size: 11))
                                    .foregroundStyle(idx < review.rating ? AppColor.warning : AppColor.textTertiary)
                            }
                        }
                    }
                    Text(review.text)
                        .font(.subheadline15)
                        .foregroundStyle(AppColor.textSecondary)
                        .lineSpacing(2)
                }
                .padding(.vertical, 6)
                Divider().background(AppColor.dividerSoft)
            }

            Button(action: onSeeAll) {
                Text("See all reviews")
                    .font(.subheadline15.weight(.medium))
                    .foregroundStyle(BrandColor.sand)
            }
        }
    }
}
