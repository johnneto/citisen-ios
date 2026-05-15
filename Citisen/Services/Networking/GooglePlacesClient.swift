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

    func findPlaceId(text: String, near center: CLLocationCoordinate2D) async throws -> String? {
        let key = try keychain.requireString(AppConfig.Secrets.googlePlacesKey)

        var components = URLComponents(string: AppConfig.Endpoints.placesFindFromText)!
        components.queryItems = [
            URLQueryItem(name: "input", value: text),
            URLQueryItem(name: "inputtype", value: "textquery"),
            URLQueryItem(name: "fields", value: "place_id"),
            URLQueryItem(
                name: "locationbias",
                value: "circle:5000@\(center.latitude),\(center.longitude)"
            ),
            URLQueryItem(name: "key", value: key)
        ]
        guard let url = components.url else {
            throw SpotsError.placesUnauthorized
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let response: FindPlaceResponse = try await http.send(request)
        try checkStatus(response.status, errorMessage: response.errorMessage)
        return response.candidates?.first?.placeId
    }

    func placeDetails(placeId: String) async throws -> PlaceDetailsPayload? {
        let key = try keychain.requireString(AppConfig.Secrets.googlePlacesKey)

        var components = URLComponents(string: AppConfig.Endpoints.placesDetails)!
        components.queryItems = [
            URLQueryItem(name: "place_id", value: placeId),
            URLQueryItem(name: "fields", value: AppConfig.Endpoints.placeDetailsFields),
            URLQueryItem(name: "key", value: key)
        ]
        guard let url = components.url else {
            throw SpotsError.placesUnauthorized
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let response: PlaceDetailsResponse = try await http.send(request)
        try checkStatus(response.status, errorMessage: response.errorMessage)
        return response.result
    }

    private func checkStatus(_ status: String, errorMessage: String?) throws {
        switch status {
        case "OK", "ZERO_RESULTS":
            return
        case "OVER_QUERY_LIMIT":
            throw SpotsError.placesQuota
        case "REQUEST_DENIED", "INVALID_REQUEST":
            AppLog.places.error("Google Places error: \(status, privacy: .public) \(errorMessage ?? "", privacy: .public)")
            throw SpotsError.placesUnauthorized
        default:
            AppLog.places.error("Unknown Google Places status: \(status, privacy: .public)")
            throw SpotsError.aiUnavailable(errorMessage ?? status)
        }
    }
}
