import SwiftUI

struct FilterBarView: View {
    @Bindable var viewModel: SavedPlacesViewModel

    var body: some View {
        HStack(spacing: 0) {
            ForEach(GroupingCriterion.allCases) { criterion in
                let isSelected = viewModel.selectedGroupingCriterion == criterion
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.selectedGroupingCriterion = criterion
                    }
                } label: {
                    VStack(spacing: 0) {
                        Text(criterion.rawValue)
                            .font(.caption.weight(isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? AppColor.textPrimary : AppColor.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)

                        Rectangle()
                            .fill(isSelected ? BrandColor.sand : Color.clear)
                            .frame(height: 2)
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.selectedGroupingCriterion)
            }
        }
    }
}
