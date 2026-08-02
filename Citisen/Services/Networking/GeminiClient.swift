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
                maxOutputTokens: 8192,
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

    func buildPrompt(
        city: City,
        mode: TravelMode,
        minCount: Int,
        maxCount: Int
    ) -> String {
        """
        You are a discerning local travel curator for \(city.name), \(city.country).

        TASK
        Suggest between \(minCount) and \(maxCount) \(mode.displayName) spots for a visitor, \
        covering the whole city — historic core, residential neighborhoods, emerging areas, \
        and outskirts worth the trip. This is a curated city-wide shortlist of standouts \
        (nearby, radius-based coverage is handled by a separate system). Order by relevance, \
        most essential first.

        MODE FOCUS
        \(mode.promptInstructions)

        NAMING — CRITICAL
        - "name" must be the venue's official name EXACTLY as it appears on its public Google \
        Maps listing, in the local language and spelling (e.g. "Mosteiro dos Jerónimos", not \
        "Jeronimos Monastery"; "Café A Brasileira", not "A Brasileira Cafe").
        - Never translate, transliterate, shorten, or add descriptive words to the name.
        - Each entry must be one concrete venue or landmark with its own Google Maps listing — \
        no districts, streets, events, or vague areas (a named market hall or park is fine).
        - If several venues share a similar name, pick the flagship or original location and \
        set "neighborhood" to disambiguate.

        SELECTION RULES
        - Exclude global chains (e.g. Starbucks, McDonald's). Local or regional chains are \
        allowed only when they are genuinely part of local culture.
        - Prefer places locals actually use and rate highly; skip tourist traps that survive \
        on location alone.
        - No duplicates. Spread picks across distinct neighborhoods — do not cluster near one point.

        OUTPUT FIELDS
        - "neighborhood": short district name.
        - "rationale": one sentence, maximum 15 words, on why it is worth a visit.
        - "primaryType": the venue's Google Places primary type. Choose ONLY from this list: \
        \(mode.typePalette.joined(separator: ", ")). If none fits, omit the field — a wrong \
        type hides the venue.
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
