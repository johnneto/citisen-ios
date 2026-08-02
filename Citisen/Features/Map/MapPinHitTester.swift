import CoreLocation
import MapKit
import SwiftUI

/// Resolves which place pin — if any — a tap on the map landed on.
///
/// Pins are drawn with `allowsHitTesting(false)` so MapKit keeps every touch for
/// its own pan/pinch/rotate recognizers. An annotation view consumes the touch
/// that lands on it, and a pinch needs *both* touches, so a finger starting on a
/// pin used to swallow the whole gesture and the map simply never zoomed. That
/// hit zoom-in hardest, since you pinch open around the very cluster of pins
/// you're trying to get closer to.
///
/// Matching happens in screen space rather than by map distance, so a pin's tap
/// target stays a comfortable ~48pt at every zoom level instead of growing and
/// shrinking with the map scale.
struct MapPinHitTester {
    /// Screen-space radius around a pin's anchor that counts as a tap on it.
    static let tapRadius: CGFloat = 24

    let proxy: MapProxy

    func isHit(_ place: Place, at point: CGPoint) -> Bool {
        distance(from: point, to: place) != nil
    }

    /// The nearest pin within the tap radius, or nil when the tap landed on bare map.
    func nearest(to point: CGPoint, among places: [Place]) -> Place? {
        var best: (place: Place, distance: CGFloat)?
        for place in places {
            guard let distance = distance(from: point, to: place) else { continue }
            guard let current = best else {
                best = (place, distance)
                continue
            }
            if distance < current.distance {
                best = (place, distance)
            }
        }
        return best?.place
    }

    /// Distance in points from `point` to `place`'s pin, or nil when the pin is
    /// off-screen or beyond the tap radius.
    private func distance(from point: CGPoint, to place: Place) -> CGFloat? {
        guard let anchor = proxy.convert(place.coordinate.clLocation, to: .local) else { return nil }
        let distance = hypot(point.x - anchor.x, point.y - anchor.y)
        return distance <= Self.tapRadius ? distance : nil
    }
}
