import CoreLocation
import SwiftUI

struct UserHeadingAnnotation: View {
    let heading: CLHeading?
    let mapHeading: Double

    private let dotDiameter: CGFloat = 18
    private let coneRadius: CGFloat = 42

    // Continuous (un-wrapped) bearing so SwiftUI's rotation animates the
    // shortest path across the 0°/360° seam instead of spinning the long way.
    @State private var displayedBearing: Double?
    @State private var displayedSpread: Double = 70

    var body: some View {
        ZStack {
            if let bearing = displayedBearing {
                ConeShape(spreadDegrees: displayedSpread, radius: coneRadius)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color(red: 0.0, green: 0.48, blue: 1.0).opacity(0.7), location: 0.0),
                                .init(color: Color(red: 0.0, green: 0.48, blue: 1.0).opacity(0.35), location: 0.45),
                                .init(color: Color(red: 0.0, green: 0.48, blue: 1.0).opacity(0.0), location: 1.0)
                            ]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: coneRadius * 2, height: coneRadius * 2)
                    .rotationEffect(.degrees(bearing - mapHeading))
                    .allowsHitTesting(false)
            }

            Circle()
                .fill(.white)
                .frame(width: dotDiameter + 4, height: dotDiameter + 4)
                .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)

            Circle()
                .fill(Color(red: 0.0, green: 0.48, blue: 1.0))
                .frame(width: dotDiameter, height: dotDiameter)
        }
        .animation(.easeInOut(duration: 0.45), value: displayedBearing)
        .animation(.easeInOut(duration: 0.45), value: mapHeading)
        .animation(.easeInOut(duration: 0.35), value: displayedSpread)
        .onChange(of: rawBearing) { _, new in
            updateBearing(new)
        }
        .onChange(of: rawSpread) { _, new in
            if let new { displayedSpread = new }
        }
        .onAppear {
            updateBearing(rawBearing)
            if let spread = rawSpread { displayedSpread = spread }
        }
        .accessibilityElement()
        .accessibilityLabel("Your location")
    }

    private var rawBearing: Double? {
        guard let heading else { return nil }
        let value = heading.trueHeading >= 0 ? heading.trueHeading : heading.magneticHeading
        return value >= 0 ? value : nil
    }

    private var rawSpread: Double? {
        guard let heading else { return nil }
        let accuracy = heading.headingAccuracy
        guard accuracy >= 0 else { return nil }
        // Apple-Maps-like: wider baseline that tightens only slightly with good accuracy.
        return min(max(accuracy * 2.2, 55), 95)
    }

    private func updateBearing(_ new: Double?) {
        guard let new else {
            displayedBearing = nil
            return
        }
        guard let current = displayedBearing else {
            displayedBearing = new
            return
        }
        // Shortest-path delta around the circle, applied to the un-wrapped
        // continuous value so SwiftUI animates the short way.
        let currentMod = current.truncatingRemainder(dividingBy: 360)
        let normalized = currentMod < 0 ? currentMod + 360 : currentMod
        var delta = new - normalized
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        // Small dead-zone to suppress single-degree shimmer without making the
        // cone feel laggy on real turns.
        guard abs(delta) > 0.8 else { return }
        displayedBearing = current + delta
    }
}

private struct ConeShape: Shape {
    var spreadDegrees: Double
    var radius: CGFloat

    var animatableData: Double {
        get { spreadDegrees }
        set { spreadDegrees = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let half = Angle.degrees(spreadDegrees / 2)
        let start = Angle.degrees(-90) - half
        let end = Angle.degrees(-90) + half
        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
        path.closeSubpath()
        return path
    }
}
