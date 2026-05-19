import SwiftUI

struct SaveRatingMenu: View {
    let current: SavedSpotRating?
    let onPick: (SavedSpotRating) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(SavedSpotRating.allCases) { rating in
                Button {
                    onPick(rating)
                } label: {
                    RatingPill(rating: rating, isSelected: rating == current)
                }
                .buttonStyle(.pressableScale)
            }
        }
        .padding(6)
        .frame(minWidth: 240)
        .liquidGlass(corner: Radius.xl, strength: .thick, interactive: true)
        .transition(.scale(scale: 0.6, anchor: .bottomTrailing).combined(with: .opacity))
    }
}
