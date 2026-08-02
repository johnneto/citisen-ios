import Foundation

// MARK: - Request

struct SearchTextRequest: Encodable {
    let textQuery: String
    let locationBias: LocationBias
    let maxResultCount: Int
    let includedType: String?
    let strictTypeFiltering: Bool?

    struct LocationBias: Encodable {
        let circle: Circle

        struct Circle: Encodable {
            let center: LatLngV1
            let radius: Double
        }
    }

    private enum CodingKeys: String, CodingKey {
        case textQuery, locationBias, maxResultCount, includedType, strictTypeFiltering
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(textQuery, forKey: .textQuery)
        try container.encode(locationBias, forKey: .locationBias)
        try container.encode(maxResultCount, forKey: .maxResultCount)
        try container.encodeIfPresent(includedType, forKey: .includedType)
        try container.encodeIfPresent(strictTypeFiltering, forKey: .strictTypeFiltering)
    }
}

// MARK: - Response

struct SearchTextResponse: Decodable {
    let places: [PlaceV1]?
}

struct PlaceV1: Decodable {
    let id: String
    let displayName: LocalizedText?
    let formattedAddress: String?
    let location: LatLngV1?
    let rating: Double?
    let userRatingCount: Int?
    let priceLevel: String?
    let primaryType: String?
    let types: [String]?
    let regularOpeningHours: OpeningHoursV1?
    let currentOpeningHours: OpeningHoursV1?
    let websiteUri: String?
    let nationalPhoneNumber: String?
    let internationalPhoneNumber: String?
    let reviews: [ReviewV1]?
    let editorialSummary: LocalizedText?
    let photos: [PhotoV1]?
    let addressComponents: [AddressComponentV1]?
    let businessStatus: String?
}

struct AddressComponentV1: Decodable {
    let longText: String?
    let shortText: String?
    let types: [String]?
}

// MARK: - Autocomplete (New)

struct AutocompleteRequest: Encodable {
    let input: String
    let sessionToken: String
    let locationBias: SearchTextRequest.LocationBias?
    let includedPrimaryTypes: [String]?
    let languageCode: String?

    private enum CodingKeys: String, CodingKey {
        case input, sessionToken, locationBias, includedPrimaryTypes, languageCode
    }

    // Hand-written so nil fields are omitted rather than sent as `null` — the
    // synthesized encoder emits explicit nulls, and Places rejects a null
    // `locationBias`. Mirrors `SearchTextRequest.encode(to:)`.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(input, forKey: .input)
        try container.encode(sessionToken, forKey: .sessionToken)
        try container.encodeIfPresent(locationBias, forKey: .locationBias)
        try container.encodeIfPresent(includedPrimaryTypes, forKey: .includedPrimaryTypes)
        try container.encodeIfPresent(languageCode, forKey: .languageCode)
    }
}

struct AutocompleteResponse: Decodable {
    let suggestions: [AutocompleteSuggestion]?
}

struct AutocompleteSuggestion: Decodable {
    let placePrediction: PlacePrediction?
}

struct PlacePrediction: Decodable {
    let placeId: String?
    let text: FormattableText?
    let structuredFormat: StructuredFormat?
    let types: [String]?
}

struct FormattableText: Decodable {
    let text: String?
}

struct StructuredFormat: Decodable {
    let mainText: FormattableText?
    let secondaryText: FormattableText?
}

struct PhotoV1: Decodable {
    let name: String
    let widthPx: Int?
    let heightPx: Int?
    let authorAttributions: [AuthorAttribution]?
}

struct LocalizedText: Decodable {
    let text: String?
    let languageCode: String?
}

struct LatLngV1: Codable {
    let latitude: Double
    let longitude: Double
}

struct OpeningHoursV1: Decodable {
    let openNow: Bool?
    let weekdayDescriptions: [String]?
}

struct ReviewV1: Decodable {
    let rating: Int?
    let text: LocalizedText?
    let relativePublishTimeDescription: String?
    let publishTime: String?
    let authorAttribution: AuthorAttribution?
}

struct AuthorAttribution: Decodable {
    let displayName: String?
}

// MARK: - Error envelope

struct PlacesErrorEnvelope: Decodable {
    let error: PlacesErrorBody
}

struct PlacesErrorBody: Decodable {
    let code: Int?
    let message: String?
    let status: String?
}
