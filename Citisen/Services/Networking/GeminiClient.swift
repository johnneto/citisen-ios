import CoreLocation
import Foundation
import OSLog

final class GeminiClient {
    private let http: HTTPClient
    private let keychain: KeychainService

    init(http: HTTPClient = .shared, keychain: KeychainService = .shared) {
        self.http = http
        self.keychain = keychain
    }

    func curatedSpots(
        city: City,
        mode: TravelMode,
        viewport: Viewport,
        minCount: Int,
        maxCount: Int
    ) async throws -> [CuratedSpot] {
        let key = try keychain.requireString(AppConfig.Secrets.geminiKey)

        guard var components = URLComponents(string: AppConfig.Endpoints.geminiGenerateContent) else {
            throw SpotsError.aiUnavailable("Bad Gemini URL")
        }
        components.queryItems = [URLQueryItem(name: "key", value: key)]
        guard let url = components.url else {
            throw SpotsError.aiUnavailable("Bad Gemini URL")
        }

        let prompt = buildPrompt(city: city, mode: mode, viewport: viewport, minCount: minCount, maxCount: maxCount)
        let body = GeminiRequest(
            contents: [GeminiContent(role: "user", parts: [GeminiPart(text: prompt)])],
            generationConfig: GeminiGenerationConfig(
                responseMimeType: "application/json",
                responseSchema: .curatedSpotsArray,
                temperature: 0.7,
                maxOutputTokens: 4096
            )
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        AppLog.ai.debug("Gemini request city=\(city.id, privacy: .public) mode=\(mode.rawValue, privacy: .public) min=\(minCount) max=\(maxCount)")

        let response: GeminiResponse = try await http.send(request)

        if let geminiError = response.error {
            throw SpotsError.aiUnavailable(geminiError.message)
        }

        guard let text = response.candidates?.first?.content?.parts?.first?.text else {
            throw SpotsError.aiUnavailable("Empty Gemini response")
        }

        guard let textData = text.data(using: .utf8) else {
            throw SpotsError.aiBadJSON
        }

        do {
            return try JSONDecoder().decode([CuratedSpot].self, from: textData)
        } catch {
            AppLog.ai.error("Gemini JSON decode failed: \(error.localizedDescription, privacy: .public)")
            throw SpotsError.aiBadJSON
        }
    }

    private func buildPrompt(
        city: City,
        mode: TravelMode,
        viewport: Viewport,
        minCount: Int,
        maxCount: Int
    ) -> String {
        let lat = String(format: "%.5f", viewport.center.latitude)
        let lng = String(format: "%.5f", viewport.center.longitude)
        let radius = String(format: "%.1f", max(viewport.radiusKm, 1.0))

        let constraints = [
            "avoid common global chains unless regional",
            "prefer places locals actually use",
            "mix neighborhoods",
            "avoid duplicates",
            "follow instructions of minimum and maximum of suggestions",
            "order the response by relevance with most relevant suggestions first on the list"
        ].joined(separator: ", ")

        return """
        You are a local travel guide for \(city.name), \(city.country).
        Suggest between \(minCount) and \(maxCount) \(mode.displayName) spots within ~\(radius) km of (\(lat),\(lng)).
        \(mode.promptInstructions)
        HARD CONSTRAINTS: \(constraints).
        Return JSON only — array of objects with name, neighborhood, one-sentence rationale.
        """
    }
}
