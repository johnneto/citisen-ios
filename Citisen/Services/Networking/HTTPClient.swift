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
            if http.statusCode == 401 || http.statusCode == 403 {
                throw SpotsError.placesUnauthorized
            }
            if http.statusCode == 429 {
                throw SpotsError.placesQuota
            }
            let body = String(data: data, encoding: .utf8)?.prefix(200).description
            throw SpotsError.aiUnavailable(body)
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
                if http.statusCode == 401 || http.statusCode == 403 {
                    throw SpotsError.placesUnauthorized
                }
                if http.statusCode == 429 {
                    throw SpotsError.placesQuota
                }
                let body = String(data: data, encoding: .utf8)?.prefix(200).description
                throw SpotsError.aiUnavailable(body)
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
}
