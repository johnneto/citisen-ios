import CoreLocation
import Foundation
import OSLog

final class GooglePlacesClient {
    private let http: HTTPClient
    private let keychain: KeychainService

    init(http: HTTPClient = .shared, keychain: KeychainService = .shared) {
        self.http = http
        self.keychain = keychain
    }

    func searchText(
        query: String,
        near center: CLLocationCoordinate2D,
        radius: Double = 5_000
    ) async throws -> PlaceV1? {
        let key = try keychain.requireString(AppConfig.Secrets.googlePlacesKey)

        guard let url = URL(string: AppConfig.Endpoints.placesSearchText) else {
            throw SpotsError.placesUnauthorized(detail: nil)
        }

        let payload = SearchTextRequest(
            textQuery: query,
            locationBias: .init(
                circle: .init(
                    center: LatLngV1(latitude: center.latitude, longitude: center.longitude),
                    radius: radius
                )
            ),
            maxResultCount: 1
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue(AppConfig.Endpoints.searchTextFieldMask, forHTTPHeaderField: "X-Goog-FieldMask")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(payload)

        let response: SearchTextResponse = try await http.send(request)
        return response.places?.first
    }

    func placeDetails(id placeId: String) async throws -> PlaceV1? {
        let key = try keychain.requireString(AppConfig.Secrets.googlePlacesKey)

        guard let url = URL(string: "\(AppConfig.Endpoints.placesDetailsBase)/\(placeId)") else {
            throw SpotsError.placesUnauthorized(detail: nil)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(key, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue(AppConfig.Endpoints.placeDetailsFieldMask, forHTTPHeaderField: "X-Goog-FieldMask")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let place: PlaceV1 = try await http.send(request)
        return place
    }

    /// Builds a Places API (New) photo media URL for an `AsyncImage` to load.
    /// The API key is appended as `?key=` because `AsyncImage` cannot set headers.
    /// Returns nil if the key is unavailable — caller falls back to a placeholder.
    func photoMediaURL(
        name: String,
        maxWidthPx: Int = AppConfig.Spots.photoMaxWidthPx,
        maxHeightPx: Int = AppConfig.Spots.photoMaxHeightPx
    ) -> URL? {
        guard let key = try? keychain.requireString(AppConfig.Secrets.googlePlacesKey) else {
            return nil
        }
        var components = URLComponents(string: "\(AppConfig.Endpoints.placesBase)/\(name)/media")
        components?.queryItems = [
            URLQueryItem(name: "maxWidthPx", value: String(maxWidthPx)),
            URLQueryItem(name: "maxHeightPx", value: String(maxHeightPx)),
            URLQueryItem(name: "key", value: key)
        ]
        return components?.url
    }
}
