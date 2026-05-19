import SwiftUI

struct SubFilterBar: View {
    let mode: TravelMode
    @Binding var active: Set<SubFilter>

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SubFilter.allCases) { filter in
                    PillFilter(
                        label: filter.label,
                        iconSymbol: filter.iconSymbol,
                        mode: mode,
                        isActive: active.contains(filter)
                    ) {
                        if active.contains(filter) { active.remove(filter) } else { active.insert(filter) }
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
        }
    }
}
