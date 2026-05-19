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

        let prompt = buildPrompt(city: city, mode: mode, minCount: minCount, maxCount: maxCount)
        let body = GeminiRequest(
            contents: [GeminiContent(role: "user", parts: [GeminiPart(text: prompt)])],
            generationConfig: GeminiGenerationConfig(
                responseMimeType: "application/json",
                responseSchema: .curatedSpotsArray,
                temperature: 0.7,
                maxOutputTokens: 4096,
                thinkingConfig: GeminiThinkingConfig(thinkingBudget: 0)
            )
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        request.timeoutInterval = 45

        AppLog.ai.debug("Gemini request city=\(city.id, privacy: .public) mode=\(mode.rawValue, privacy: .public) min=\(minCount) max=\(maxCount)")

        let response: GeminiResponse = try await sendWithTimeoutRetry(request)

        if let geminiError = response.error {
            throw SpotsError.aiUnavailable(geminiError.message)
        }

        let candidate = response.candidates?.first
        let finishReason = candidate?.finishReason ?? "-"

        guard let text = candidate?.content?.parts?.first?.text else {
            AppLog.ai.error("Empty Gemini response — finishReason=\(finishReason, privacy: .public)")
            throw SpotsError.aiUnavailable("Empty Gemini response (\(finishReason))")
        }

        guard let textData = text.data(using: .utf8) else {
            throw SpotsError.aiBadJSON
        }

        do {
            return try JSONDecoder().decode([CuratedSpot].self, from: textData)
        } catch {
            AppLog.ai.error("Gemini JSON decode failed — finishReason=\(finishReason, privacy: .public) err=\(error.localizedDescription, privacy: .public)")
            throw SpotsError.aiBadJSON
        }
    }

    private func buildPrompt(
        city: City,
        mode: TravelMode,
        minCount: Int,
        maxCount: Int
    ) -> String {
        let constraints = [
            "avoid common global chains unless regional",
            "prefer places locals actually use",
            "spread results across distinct neighborhoods — do not cluster near one point",
            "do not show duplicates",
            "exclude global chains",
            "order the response by relevance with most relevant suggestions first on the list"
        ].joined(separator: ", ")

        let primaryTypeGuidance = """
        For each spot, also set "primaryType" to the single Google Places (New) primary type \
        string that best matches the venue. Use the exact snake_case identifier (no display \
        formatting). Examples of valid values: restaurant, cafe, bar, bakery, night_club, \
        church, mosque, synagogue, hindu_temple, place_of_worship, museum, art_gallery, \
        library, historical_landmark, tourist_attraction, monument, park, garden, beach, zoo, \
        aquarium, book_store, shopping_mall, clothing_store, market, hotel, lodging, gym, spa, \
        yoga_studio, theater, movie_theater, stadium, concert_hall, amusement_park, viewpoint. \
        If unsure, omit primaryType rather than guess — a wrong value will filter out the \
        correct place.
        """

        let scope = """
        Suggest between \(minCount) and \(maxCount) \(mode.displayName) highlights across the \
        entire city of \(city.name) — cover the whole city perimeter (historic core, residential \
        pockets, emerging areas, outskirts worth the trip), not just one area.
        """

        let framing = """
        Treat this as a curated city-wide shortlist of standouts; nearby and radius-based \
        coverage is handled separately by another system, so focus on the very best of the \
        city as a whole rather than what is closest to any single point.
        """

        return """
        Target city: \(city.name), \(city.country).
        You are a local travel guide for \(city.name), \(city.country).
        \(scope)
        \(framing)
        \(mode.promptInstructions)
        HARD CONSTRAINTS: \(constraints).
        \(primaryTypeGuidance)
        """
    }

    private func sendWithTimeoutRetry(_ request: URLRequest) async throws -> GeminiResponse {
        do {
            return try await http.send(request)
        } catch SpotsError.timeout {
            AppLog.ai.debug("Gemini timed out — retrying once")
            try await Task.sleep(nanoseconds: 500_000_000)
            try Task.checkCancellation()
            return try await http.send(request)
        }
    }
}
