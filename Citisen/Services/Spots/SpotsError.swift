import Foundation

enum SpotsError: Error, LocalizedError {
    case offline
    case timeout
    case aiUnavailable(String?)
    case aiBadJSON
    case placesQuota(detail: String?)
    case placesUnauthorized(detail: String?)
    case placesNotFound(String)
    case missingAPIKey(String)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .offline:
            return "You're offline. Connect to the internet and try again."
        case .timeout:
            return "The request timed out. Try again in a moment."
        case .aiUnavailable(let detail):
            return detail.map { "AI curation is unavailable — \($0)" } ?? "AI curation is unavailable right now."
        case .aiBadJSON:
            return "Couldn't read the AI response. Try again."
        case .placesQuota(let detail):
            return detail.map { "Hit the Google Places quota — \($0)" }
                ?? "Hit the Google Places quota — try again later."
        case .placesUnauthorized(let detail):
            return detail.map { "Google Places rejected the request: \($0)" }
                ?? "Google Places rejected the request. Check the API key."
        case .placesNotFound(let name):
            return "Couldn't locate \"\(name)\" on Google Places."
        case .missingAPIKey(let key):
            return "Missing API key: \(key)."
        case .unknown(let error):
            return error.localizedDescription
        }
    }

    static func mapURLError(_ error: URLError) -> SpotsError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
            return .offline
        case .timedOut:
            return .timeout
        default:
            return .unknown(error)
        }
    }
}
