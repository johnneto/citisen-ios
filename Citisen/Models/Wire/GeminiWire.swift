import Foundation

struct CuratedSpot: Codable, Hashable {
    let name: String
    let neighborhood: String?
    let rationale: String?
}

struct GeminiRequest: Encodable {
    let contents: [GeminiContent]
    let generationConfig: GeminiGenerationConfig
}

struct GeminiContent: Encodable {
    let role: String
    let parts: [GeminiPart]
}

struct GeminiPart: Encodable {
    let text: String
}

struct GeminiGenerationConfig: Encodable {
    let responseMimeType: String
    let responseSchema: GeminiSchema
    let temperature: Double
    let maxOutputTokens: Int
    let thinkingConfig: GeminiThinkingConfig?
}

struct GeminiThinkingConfig: Encodable {
    let thinkingBudget: Int
}

struct GeminiSchema: Encodable {
    let type: String
    let items: GeminiSchemaItems?

    static let curatedSpotsArray = GeminiSchema(
        type: "ARRAY",
        items: GeminiSchemaItems(
            type: "OBJECT",
            properties: [
                "name": GeminiSchemaProperty(type: "STRING"),
                "neighborhood": GeminiSchemaProperty(type: "STRING"),
                "rationale": GeminiSchemaProperty(type: "STRING")
            ],
            required: ["name"]
        )
    )
}

struct GeminiSchemaItems: Encodable {
    let type: String
    let properties: [String: GeminiSchemaProperty]
    let required: [String]
}

struct GeminiSchemaProperty: Encodable {
    let type: String
}

struct GeminiResponse: Decodable {
    let candidates: [GeminiCandidate]?
    let error: GeminiError?
}

struct GeminiCandidate: Decodable {
    let content: GeminiCandidateContent?
    let finishReason: String?
}

struct GeminiCandidateContent: Decodable {
    let parts: [GeminiCandidatePart]?
}

struct GeminiCandidatePart: Decodable {
    let text: String?
}

struct GeminiError: Decodable {
    let code: Int?
    let message: String?
    let status: String?
}
