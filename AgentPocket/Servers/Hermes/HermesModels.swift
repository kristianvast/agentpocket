import Foundation

// MARK: - Hermes Health and Models

struct HermesHealthResponse: Decodable, Sendable {
    let status: String?
}

struct HermesModelsResponse: Decodable, Sendable {
    let data: [HermesModel]
}

struct HermesModel: Decodable, Sendable {
    let id: String
}

// MARK: - Hermes Responses API

struct HermesResponsesRequest: Encodable, Sendable {
    let model: String
    let input: String
    let stream: Bool
    let previousResponseID: String?
}

struct HermesResponseStreamEvent: Decodable, Sendable {
    let type: String
    let response: HermesResponseObject?
    let responseID: String?
    let delta: String?
    let item: HermesResponseItem?
}

struct HermesResponseObject: Decodable, Sendable {
    let id: String
    let status: String?
}

struct HermesResponseItem: Decodable, Sendable {
    let id: String?
    let type: String?
    let name: String?
    let status: String?
    let arguments: String?
    let output: String?
}

// MARK: - Hermes Chat Completions Fallback

struct HermesChatCompletionsRequest: Encodable, Sendable {
    let model: String
    let stream: Bool
    let messages: [HermesChatCompletionMessage]
}

struct HermesChatCompletionMessage: Codable, Sendable {
    let role: String
    let content: String
}

struct HermesChatCompletionChunk: Decodable, Sendable {
    let choices: [HermesChatCompletionChoice]
}

struct HermesChatCompletionChoice: Decodable, Sendable {
    let delta: HermesChatCompletionDelta?
    let finishReason: String?
}

struct HermesChatCompletionDelta: Decodable, Sendable {
    let content: String?
}
