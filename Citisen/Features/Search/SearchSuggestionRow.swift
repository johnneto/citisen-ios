import SwiftUI

/// One autocomplete suggestion. Cities get the brand tint and a departure glyph
/// (tapping opens the travel confirmation); places get the active travel mode's
/// colours and a disclosure chevron, matching the map pins.
struct SearchSuggestionRow: View {
    let suggestion: SearchSuggestion
    let mode: TravelMode
    let isResolving: Bool

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(isCity ? BrandColor.sandTint : mode.tintColor)
                Image(systemName: suggestion.iconSymbol)
                    .foregroundStyle(isCity ? BrandColor.sandDeep : mode.color)
                    .font(.system(size: 20, weight: .semibold))
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.primaryText)
                    .font(.subheadline15.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(1)
                if !suggestion.secondaryText.isEmpty {
                    Text(suggestion.secondaryText)
                        .font(.caption12)
                        .foregroundStyle(AppColor.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            trailing
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private var isCity: Bool { suggestion.kind == .city }

    @ViewBuilder private var trailing: some View {
        if isResolving {
            ProgressView()
        } else {
            Image(systemName: isCity ? "airplane.departure" : "chevron.right")
                .font(.caption12)
                .foregroundStyle(isCity ? BrandColor.sand : AppColor.textTertiary)
        }
    }
}

struct SearchInlineSpinner: View {
    var body: some View {
        HStack(spacing: Spacing.sm) {
            ProgressView()
            Text("Searching…")
                .font(.footnote13)
                .foregroundStyle(AppColor.textSecondary)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }
}

/// Centred icon + title + hint used for the search screen's empty and error states.
struct SearchPlaceholderState: View {
    let symbol: String
    let symbolColor: Color
    let title: String?
    let message: String

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Spacer()
            Image(systemName: symbol)
                .font(.system(size: 36))
                .foregroundStyle(symbolColor)
            if let title {
                Text(title)
                    .font(.headline17)
                    .foregroundStyle(AppColor.textPrimary)
            }
            Text(message)
                .font(.footnote13)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.lg)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
