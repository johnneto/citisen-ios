import SwiftUI

/// Marks a POI card as a place the user found through search and kept, rather
/// than one the AI curation suggested. Deliberately quieter than `ModeChip` —
/// this is provenance, not a category, so it stays in the secondary text colour
/// instead of taking a mode tint.
struct FoundBySearchBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 9, weight: .semibold))
            Text("YOUR SEARCH")
                .font(.caption11Bold)
                .tracking(0.8)
        }
        .foregroundStyle(AppColor.textSecondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(AppColor.surfaceGrouped)
        .clipShape(Capsule())
        .accessibilityElement()
        .accessibilityLabel("Found by your search")
    }
}
