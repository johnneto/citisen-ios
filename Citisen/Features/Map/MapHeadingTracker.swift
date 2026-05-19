import Observation

/// Holds the live map camera heading for `UserHeadingAnnotation`'s cone rotation.
///
/// The cone needs the heading to update at frame rate so it stays locked to true
/// north while the user rotates the map. We keep this off `MapViewModel` so the
/// camera-change callback can write at 60 Hz without invalidating the `Map`
/// content closure that builds the pin `ForEach` — that re-evaluation is what
/// caused pin shadows to flicker on tilt/move.
///
/// Only `UserHeadingAnnotation.body` reads `heading`, so observation is scoped
/// to that one view.
@Observable
@MainActor
final class MapHeadingTracker {
    var heading: Double = 0

    /// Dead-zone of 0.25° to drop sub-pixel jitter coming from MapKit's
    /// continuous camera stream without making the cone feel laggy.
    func update(_ new: Double) {
        if abs(new - heading) >= 0.25 {
            heading = new
        }
    }
}
