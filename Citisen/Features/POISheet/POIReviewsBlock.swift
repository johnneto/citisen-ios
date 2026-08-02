import SwiftUI

struct POIReviewsBlock: View {
    let place: Place
    let onAddReview: () -> Void
    let onSeeAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                // "Recent reviews" + rendered count so the number always matches
                // the rows below (place.reviewCount is Google's total ratings,
                // which includes text-less ratings we don't render).
                Text(place.reviews.isEmpty ? "Reviews" : "Recent reviews (\(place.reviews.count))")
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

            if place.reviews.isEmpty {
                Text("No written reviews yet.")
                    .font(.subheadline15)
                    .foregroundStyle(AppColor.textTertiary)
                    .padding(.vertical, 6)
            }

            ForEach(place.reviews) { review in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Avatar(initials: String(review.authorName.prefix(1)), size: 28)
                        Text(review.authorName)
                            .font(.footnote13.weight(.semibold))
                            .foregroundStyle(AppColor.textPrimary)
                        Text("· \(review.relativeTime ?? "\(review.daysAgo)d ago")")
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

            if !place.reviews.isEmpty {
                Button(action: onSeeAll) {
                    Text("See all reviews")
                        .font(.subheadline15.weight(.medium))
                        .foregroundStyle(BrandColor.sand)
                }
            }
        }
    }
}
