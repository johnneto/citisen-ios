import Foundation
import OSLog

final class HTTPClient {
    static let shared = HTTPClient()

    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = HTTPClient.makeSession(), decoder: JSONDecoder = JSONDecoder()) {
        self.session = session
        self.decoder = decoder
    }

    private static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }

    func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            throw SpotsError.mapURLError(urlError)
        } catch {
            throw SpotsError.unknown(error)
        }

        try Task.checkCancellation()

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw HTTPClient.mapPlacesError(httpCode: http.statusCode, data: data, request: request)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            AppLog.ai.error("HTTPClient decode failed: \(error.localizedDescription, privacy: .public)")
            throw SpotsError.aiBadJSON
        }
    }

    func sendRaw(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            try Task.checkCancellation()
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw HTTPClient.mapPlacesError(httpCode: http.statusCode, data: data, request: request)
            }
            return data
        } catch let urlError as URLError {
            throw SpotsError.mapURLError(urlError)
        } catch let spotsError as SpotsError {
            throw spotsError
        } catch {
            throw SpotsError.unknown(error)
        }
    }

    private struct GoogleErrorEnvelope: Decodable {
        struct Inner: Decodable {
            let code: Int?
            let message: String?
            let status: String?
        }
        let error: Inner
    }

    private static func mapPlacesError(httpCode: Int, data: Data, request: URLRequest) -> SpotsError {
        let rawBody = String(data: data, encoding: .utf8) ?? "<non-utf8 \(data.count) bytes>"
        let truncatedBody = rawBody.count > 2048
            ? String(rawBody.prefix(2048)) + "…[truncated]"
            : rawBody

        let envelope = try? JSONDecoder().decode(GoogleErrorEnvelope.self, from: data)
        let googleStatus = envelope?.error.status
        let googleMessage = envelope?.error.message

        AppLog.places.error(
            "Places HTTP \(httpCode, privacy: .public) \(request.httpMethod ?? "?", privacy: .public) \(request.url?.path ?? "?", privacy: .public) status=\(googleStatus ?? "-", privacy: .public) — body: \(truncatedBody, privacy: .public)"
        )

        let detail = googleMessage ?? (envelope == nil ? truncatedBody : nil)

        switch googleStatus {
        case "RESOURCE_EXHAUSTED":
            return .placesQuota(detail: detail)
        case "PERMISSION_DENIED", "UNAUTHENTICATED", "FAILED_PRECONDITION":
            return .placesUnauthorized(detail: detail)
        default:
            break
        }

        switch httpCode {
        case 401, 403:
            return .placesUnauthorized(detail: detail)
        case 429:
            return .placesQuota(detail: detail)
        default:
            return .aiUnavailable(detail ?? String(truncatedBody.prefix(200)))
        }
    }
}
