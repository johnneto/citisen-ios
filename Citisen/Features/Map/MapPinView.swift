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

                Image(systemName: mode.iconSymbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(mode.color)
            }
            Triangle()
                .fill(.white)
                .frame(width: 10, height: 8)
                .offset(y: -2)
        }
        // `compositingGroup()` flattens the head + tail into a single offscreen
        // layer so the shadow below is computed once over the composed shape,
        // not separately on each child. Without this, two overlapping shadows
        // re-rasterized on every Map content-closure re-evaluation, producing
        // the visible flicker on tilt/pan.
        .compositingGroup()
        .shadow(color: .black.opacity(0.22), radius: isSelected ? 8 : 4, x: 0, y: 3)
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
