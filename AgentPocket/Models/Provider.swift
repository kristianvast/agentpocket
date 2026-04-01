import Foundation

typealias ProviderID = String
typealias ModelID = String

struct Provider: Codable, Identifiable, Hashable, Sendable {
    var id: ProviderID
    var name: String
    var models: [String: Model]?
}

struct Model: Codable, Identifiable, Hashable, Sendable {
    var id: ModelID
    var name: String
    var family: String?
    var releaseDate: String?
    var attachment: Bool?
    var reasoning: Bool?
    var temperature: Bool?
    var toolCall: Bool?
    var cost: ModelCost?
    var limit: ModelLimit?
    var modalities: ModelModalities?
    var experimental: Bool?
    var status: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case family
        case releaseDate = "release_date"
        case attachment
        case reasoning
        case temperature
        case toolCall = "tool_call"
        case cost
        case limit
        case modalities
        case experimental
        case status
    }
}

struct ModelCost: Codable, Hashable, Sendable {
    var input: Double?
    var output: Double?
    var cacheRead: Double?
    var cacheWrite: Double?
    var reasoning: Double?

    enum CodingKeys: String, CodingKey {
        case input
        case output
        case cacheRead = "cache_read"
        case cacheWrite = "cache_write"
        case reasoning
    }
}

struct ModelLimit: Codable, Hashable, Sendable {
    var context: Int?
    var output: Int?
    var toolCalls: Int?

    enum CodingKeys: String, CodingKey {
        case context
        case output
        case toolCalls = "tool_calls"
    }
}

struct ModelModalities: Codable, Hashable, Sendable {
    var input: [String]?
    var output: [String]?
}
