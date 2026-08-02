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

    /// Text Search (New). Returns up to `maxResults` candidates in Google's
    /// ranking order so the caller can pick the official listing among dupes.
    /// Billing is per request, not per result, so asking for 5 costs the same as 1.
    func searchTextCandidates(
        query: String,
        near center: CLLocationCoordinate2D,
        radius: Double = 5_000,
        includedType: String? = nil,
        maxResults: Int = 5
    ) async throws -> [PlaceV1] {
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
            maxResultCount: maxResults,
            includedType: includedType,
            strictTypeFiltering: includedType == nil ? nil : true
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue(AppConfig.Endpoints.searchTextFieldMask, forHTTPHeaderField: "X-Goog-FieldMask")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(payload)

        let response: SearchTextResponse = try await http.send(request)
        return response.places ?? []
    }

    /// Fetches full place details. Pass the `sessionToken` from a preceding
    /// autocomplete run so Google bills both calls as one session.
    func placeDetails(id placeId: String, sessionToken: String? = nil) async throws -> PlaceV1? {
        let key = try keychain.requireString(AppConfig.Secrets.googlePlacesKey)

        guard var components = URLComponents(string: "\(AppConfig.Endpoints.placesDetailsBase)/\(placeId)") else {
            throw SpotsError.placesUnauthorized(detail: nil)
        }
        if let sessionToken {
            components.queryItems = [URLQueryItem(name: "sessionToken", value: sessionToken)]
        }
        guard let url = components.url else {
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

    /// Places Autocomplete (New). The session token should remain stable across
    /// keystrokes for a given typing session and be reused for the follow-up
    /// details call so the whole thing is billed as one autocomplete session
    /// (per Google's docs). Autocomplete takes no field mask.
    ///
    /// `center` applies a `locationBias` circle — results near it rank higher but
    /// matches outside the radius are still returned.
    func autocomplete(
        query: String,
        sessionToken: String,
        near center: CLLocationCoordinate2D? = nil,
        radius: Double = AppConfig.Search.locationBiasRadiusMeters,
        includedPrimaryTypes: [String]? = nil,
        languageCode: String? = nil
    ) async throws -> [AutocompleteSuggestion] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let key = try keychain.requireString(AppConfig.Secrets.googlePlacesKey)
        guard let url = URL(string: AppConfig.Endpoints.placesAutocomplete) else {
            throw SpotsError.placesUnauthorized(detail: nil)
        }

        let bias = center.map { coord in
            SearchTextRequest.LocationBias(
                circle: .init(
                    center: LatLngV1(latitude: coord.latitude, longitude: coord.longitude),
                    radius: radius
                )
            )
        }

        let payload = AutocompleteRequest(
            input: trimmed,
            sessionToken: sessionToken,
            locationBias: bias,
            includedPrimaryTypes: includedPrimaryTypes,
            languageCode: languageCode
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(payload)

        let response: AutocompleteResponse = try await http.send(request)
        return response.suggestions ?? []
    }

    /// Autocomplete restricted to cities/towns, projected for the city switcher.
    func autocompleteCities(
        query: String,
        sessionToken: String,
        languageCode: String? = nil
    ) async throws -> [CityPrediction] {
        let suggestions = try await autocomplete(
            query: query,
            sessionToken: sessionToken,
            includedPrimaryTypes: ["locality", "administrative_area_level_3"],
            languageCode: languageCode
        )
        return suggestions.compactMap { CityPrediction(from: $0) }
    }

    /// Fetches the minimum payload needed to construct a `City` from a Places
    /// autocomplete prediction: display name, coordinates, country name and ISO
    /// country code. Passes the same `sessionToken` used for autocomplete so the
    /// request is billed under that session.
    func cityDetails(placeId: String, sessionToken: String) async throws -> PlaceV1? {
        let key = try keychain.requireString(AppConfig.Secrets.googlePlacesKey)
        guard var components = URLComponents(string: "\(AppConfig.Endpoints.placesDetailsBase)/\(placeId)") else {
            throw SpotsError.placesUnauthorized(detail: nil)
        }
        components.queryItems = [URLQueryItem(name: "sessionToken", value: sessionToken)]
        guard let url = components.url else {
            throw SpotsError.placesUnauthorized(detail: nil)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(key, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue(AppConfig.Endpoints.cityDetailsFieldMask, forHTTPHeaderField: "X-Goog-FieldMask")
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
