import SwiftUI

struct PillFilter: View {
    let label: String
    var iconSymbol: String?
    let mode: TravelMode
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let iconSymbol {
                    Image(systemName: iconSymbol)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(label.uppercased())
                    .font(.caption11Bold)
                    .tracking(0.8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(isActive ? .white : mode.color)
            .background(isActive ? mode.color : mode.tintColor)
            .clipShape(Capsule())
            .scaleEffect(isActive ? 1.03 : 1)
            .shadow(color: mode.color.opacity(isActive ? 0.33 : 0), radius: 8, x: 0, y: 4)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isActive)
        }
        .buttonStyle(.pressableScale)
    }
}
