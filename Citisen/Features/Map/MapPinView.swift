import SwiftUI

struct MapPinView: View {
    let mode: TravelMode
    var isSelected: Bool = false

    var body: some View {
        VStack(spacing: -2) {
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(
                        width: isSelected ? 36 : 30,
                        height: isSelected ? 36 : 30
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(isSelected ? mode.color : Color.black.opacity(0.08), lineWidth: isSelected ? 2 : 0.5)
                    )
                    .shadow(color: .black.opacity(0.22), radius: isSelected ? 8 : 4, x: 0, y: 3)

                Image(systemName: mode.iconSymbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(mode.color)
            }
            Triangle()
                .fill(.white)
                .frame(width: 10, height: 8)
                .shadow(color: .black.opacity(0.12), radius: 2, x: 0, y: 1)
                .offset(y: -2)
        }
        .scaleEffect(isSelected ? 1.1 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
