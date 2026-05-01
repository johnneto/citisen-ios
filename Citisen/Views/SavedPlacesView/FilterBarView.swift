import SwiftUI

struct FilterBarView: View {
    @Bindable var viewModel: SavedPlacesViewModel

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Spacing.xs) {
                ForEach(GroupingCriterion.allCases) { criterion in
                    Button {
                        viewModel.selectedGroupingCriterion = criterion
                    } label: {
                        Text(criterion.rawValue)
                            .font(.subheadline)
                            .bold(viewModel.selectedGroupingCriterion == criterion)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(
                                viewModel.selectedGroupingCriterion == criterion
                                    ? BrandColor.sand
                                    : AppColor.surfaceGrouped
                            )
                            .foregroundStyle(
                                viewModel.selectedGroupingCriterion == criterion
                                    ? Color.white
                                    : AppColor.textPrimary
                            )
                            .clipShape(.rect(cornerRadius: Radius.md))
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
        }
        .scrollIndicators(.hidden)
        .frame(height: 44)
    }
}
