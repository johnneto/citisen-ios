import SwiftUI

struct ModeChip: View {
    let mode: TravelMode
    var style: Style = .tint
    var iconSize: CGFloat = 14

    enum Style {
        case tint       // pill background filled w/ tintColor
        case solid      // pill w/ mode.color
        case outlined   // transparent, mode color text + border
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: mode.iconSymbol)
                .font(.system(size: iconSize, weight: .semibold))
            Text(mode.displayName.uppercased())
                .font(.caption11Bold)
                .tracking(0.8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .foregroundStyle(foreground)
        .background(background)
        .overlay(
            Capsule().strokeBorder(borderColor, lineWidth: style == .outlined ? 1 : 0)
        )
        .clipShape(Capsule())
    }

    private var foreground: Color {
        switch style {
        case .solid: return .white
        case .tint, .outlined: return mode.color
        }
    }

    private var background: Color {
        switch style {
        case .solid: return mode.color
        case .tint: return mode.tintColor
        case .outlined: return .clear
        }
    }

    private var borderColor: Color {
        style == .outlined ? mode.color : .clear
    }
}
