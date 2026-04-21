import SwiftUI

struct CompassLogo: View {
    var size: CGFloat = 120
    var showPetals: Bool = true

    private let ringRatio: CGFloat = 0.44
    private let ringThickness: CGFloat = 0.055

    var body: some View {
        ZStack {
            Circle()
                .stroke(BrandColor.sand, lineWidth: size * ringThickness)
                .frame(width: size * ringRatio * 2, height: size * ringRatio * 2)

            Circle()
                .fill(Color(hex: "0D0D0D"))
                .frame(
                    width: size * (ringRatio - ringThickness / 2) * 2,
                    height: size * (ringRatio - ringThickness / 2) * 2
                )

            if showPetals {
                petals
                Circle()
                    .fill(Color(hex: "0D0D0D"))
                    .frame(width: size * 0.17, height: size * 0.17)
                Circle()
                    .fill(BrandColor.sand)
                    .frame(width: size * 0.09, height: size * 0.09)
            } else {
                // Mark-only — north arrow
                NorthArrow(color: BrandColor.sand)
                    .frame(width: size * 0.55, height: size * 0.55)
                Circle()
                    .fill(BrandColor.sand)
                    .frame(width: size * 0.08, height: size * 0.08)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var petals: some View {
        ZStack {
            Petal(startAngle: -30, endAngle: 30)
                .fill(Color(hex: "D4695E"))
            Petal(startAngle: 60, endAngle: 120)
                .fill(Color(hex: "4A8C6F"))
            Petal(startAngle: 150, endAngle: 210)
                .fill(Color(hex: "5B6BF0"))
            Petal(startAngle: 240, endAngle: 300)
                .fill(Color(hex: "B85CC8"))
        }
        .frame(width: size * ringRatio * 1.55, height: size * ringRatio * 1.55)
    }
}

private struct Petal: Shape {
    let startAngle: Double
    let endAngle: Double

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startAngle - 90),
            endAngle: .degrees(endAngle - 90),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

private struct NorthArrow: View {
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let centerX = width / 2
            let tipY = height * 0.05
            let tailY = height * 0.95
            Path { path in
                path.move(to: CGPoint(x: centerX, y: tipY))
                path.addLine(to: CGPoint(x: centerX + width * 0.12, y: height / 2))
                path.addLine(to: CGPoint(x: centerX, y: height * 0.42))
                path.addLine(to: CGPoint(x: centerX - width * 0.12, y: height / 2))
                path.closeSubpath()
            }
            .fill(color)
            Path { path in
                path.move(to: CGPoint(x: centerX, y: tailY))
                path.addLine(to: CGPoint(x: centerX + width * 0.12, y: height / 2))
                path.addLine(to: CGPoint(x: centerX, y: height * 0.58))
                path.addLine(to: CGPoint(x: centerX - width * 0.12, y: height / 2))
                path.closeSubpath()
            }
            .fill(color.opacity(0.5))
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        CompassLogo(size: 140)
        CompassLogo(size: 44, showPetals: false)
    }
    .padding()
}
