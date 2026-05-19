import CoreLocation
import MapKit

struct Viewport: Hashable {
    let center: CLLocationCoordinate2D
    let latitudeDelta: Double
    let longitudeDelta: Double

    init(center: CLLocationCoordinate2D, latitudeDelta: Double, longitudeDelta: Double) {
        self.center = center
        self.latitudeDelta = latitudeDelta
        self.longitudeDelta = longitudeDelta
    }

    init(region: MKCoordinateRegion) {
        self.center = region.center
        self.latitudeDelta = region.span.latitudeDelta
        self.longitudeDelta = region.span.longitudeDelta
    }

    var radiusKm: Double {
        max(latitudeDelta, longitudeDelta) * 111 / 2
    }

    func metersFrom(_ other: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: center.latitude, longitude: center.longitude)
            .distance(from: CLLocation(latitude: other.latitude, longitude: other.longitude))
    }

    static func == (lhs: Viewport, rhs: Viewport) -> Bool {
        lhs.center.latitude == rhs.center.latitude
            && lhs.center.longitude == rhs.center.longitude
            && lhs.latitudeDelta == rhs.latitudeDelta
            && lhs.longitudeDelta == rhs.longitudeDelta
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(center.latitude)
        hasher.combine(center.longitude)
        hasher.combine(latitudeDelta)
        hasher.combine(longitudeDelta)
    }
}
