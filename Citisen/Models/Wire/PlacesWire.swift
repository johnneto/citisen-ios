import Foundation

struct FindPlaceResponse: Decodable {
    let candidates: [FindPlaceCandidate]?
    let status: String
    let errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case candidates
        case status
        case errorMessage = "error_message"
    }
}

struct FindPlaceCandidate: Decodable {
    let placeId: String

    enum CodingKeys: String, CodingKey {
        case placeId = "place_id"
    }
}

struct PlaceDetailsResponse: Decodable {
    let result: PlaceDetailsPayload?
    let status: String
    let errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case result
        case status
        case errorMessage = "error_message"
    }
}

struct PlaceDetailsPayload: Decodable {
    let placeId: String
    let name: String?
    let formattedAddress: String?
    let geometry: PlaceGeometry?
    let rating: Double?
    let userRatingsTotal: Int?
    let priceLevel: Int?
    let types: [String]?
    let openingHours: PlaceOpeningHours?
    let currentOpeningHours: PlaceOpeningHours?
    let website: String?
    let formattedPhoneNumber: String?
    let internationalPhoneNumber: String?
    let reviews: [PlaceReview]?
    let editorialSummary: PlaceEditorialSummary?

    enum CodingKeys: String, CodingKey {
        case placeId = "place_id"
        case name
        case formattedAddress = "formatted_address"
        case geometry
        case rating
        case userRatingsTotal = "user_ratings_total"
        case priceLevel = "price_level"
        case types
        case openingHours = "opening_hours"
        case currentOpeningHours = "current_opening_hours"
        case website
        case formattedPhoneNumber = "formatted_phone_number"
        case internationalPhoneNumber = "international_phone_number"
        case reviews
        case editorialSummary = "editorial_summary"
    }
}

struct PlaceGeometry: Decodable {
    let location: PlaceLatLng
}

struct PlaceLatLng: Decodable {
    let lat: Double
    let lng: Double
}

struct PlaceOpeningHours: Decodable {
    let openNow: Bool?
    let weekdayText: [String]?

    enum CodingKeys: String, CodingKey {
        case openNow = "open_now"
        case weekdayText = "weekday_text"
    }
}

struct PlaceReview: Decodable {
    let authorName: String?
    let rating: Int?
    let text: String?
    let relativeTimeDescription: String?
    let time: TimeInterval?

    enum CodingKeys: String, CodingKey {
        case authorName = "author_name"
        case rating
        case text
        case relativeTimeDescription = "relative_time_description"
        case time
    }
}

struct PlaceEditorialSummary: Decodable {
    let overview: String?
}
