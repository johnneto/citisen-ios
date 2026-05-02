import SwiftUI

struct ModePickerSheet: View {
    let currentMode: TravelMode
    var excluded: Set<TravelMode> = []
    let onPick: (TravelMode) -> Void
    let onCancel: () -> Void

    private var options: [TravelMode] {
        TravelMode.customizable
    }

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(options) { mode in
                        Button {
                            onPick(mode)
                        } label: {
                            row(for: mode)
                        }
                        .buttonStyle(.pressableScale)
                        .disabled(excluded.contains(mode))
                        .opacity(excluded.contains(mode) ? 0.35 : 1)
                    }
                }
                .padding(Spacing.md)
            }
            .navigationTitle("Choose a mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .tint(BrandColor.sand)
                }
            }
        }
    }

    private func row(for mode: TravelMode) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(.white)
                Image(systemName: mode.iconSymbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(mode.color)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 1) {
                Text(mode.displayName.uppercased())
                    .font(.caption11Bold)
                    .tracking(0.8)
                    .foregroundStyle(mode.color)
                Text(mode.tagline)
                    .font(.caption12)
                    .foregroundStyle(AppColor.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(mode.tintColor)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .strokeBorder(mode == currentMode ? mode.color : .clear, lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
    }
}
