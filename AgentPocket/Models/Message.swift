import Foundation

typealias MessageID = String

struct Message: Codable, Identifiable, Hashable, Sendable {
    let id: MessageID
    var sessionID: SessionID
    var role: MessageRole
    var time: MessageTime
    var error: MessageError?
    var agent: String?
    var model: ModelReference?
    var system: String?
    var format: OutputFormat?
    var parentID: MessageID?
    var modelID: String?
    var providerID: String?
    var cost: Double?
    var tokens: TokenUsage?
    var finish: String?
    var summary: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case sessionID = "session_id"
        case role
        case time
        case error
        case agent
        case model
        case system
        case format
        case parentID = "parent_id"
        case modelID = "model_id"
        case providerID = "provider_id"
        case cost
        case tokens
        case finish
        case summary
    }
}

enum MessageRole: String, Codable, Hashable, Sendable {
    case user
    case assistant
}

struct MessageTime: Codable, Hashable, Sendable {
    var created: Double
    var completed: Double?
}

struct ModelReference: Codable, Hashable, Sendable {
    var providerID: String
    var modelID: String

    enum CodingKeys: String, CodingKey {
        case providerID = "provider_id"
        case modelID = "model_id"
    }
}

struct TokenUsage: Codable, Hashable, Sendable {
    var input: Int
    var output: Int
    var reasoning: Int?
    var cache: CacheUsage?
    var total: Int?
}

struct CacheUsage: Codable, Hashable, Sendable {
    var read: Int
    var write: Int
}

enum OutputFormat: Codable, Hashable, Sendable {
    case text
    case jsonSchema(schema: [String: AnyCodableValue], retryCount: Int?)

    enum CodingKeys: String, CodingKey {
        case type
        case schema
        case retryCount = "retry_count"
    }

    enum Kind: String, Codable {
        case text
        case jsonSchema = "json-schema"
    }

    init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(),
           let raw = try? single.decode(String.self),
           raw == Kind.text.rawValue {
            self = .text
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .type)
        switch kind {
        case .text:
            self = .text
        case .jsonSchema:
            let schema = try container.decodeIfPresent([String: AnyCodableValue].self, forKey: .schema) ?? [:]
            let retryCount = try container.decodeIfPresent(Int.self, forKey: .retryCount)
            self = .jsonSchema(schema: schema, retryCount: retryCount)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text:
            try container.encode(Kind.text, forKey: .type)
        case .jsonSchema(let schema, let retryCount):
            try container.encode(Kind.jsonSchema, forKey: .type)
            try container.encode(schema, forKey: .schema)
            try container.encodeIfPresent(retryCount, forKey: .retryCount)
        }
    }
}

struct MessageError: Codable, Hashable, Sendable {
    var name: String
    var message: String?
    var providerID: String?
    var statusCode: Int?
    var isRetryable: Bool?

    enum CodingKeys: String, CodingKey {
        case name
        case message
        case providerID = "provider_id"
        case statusCode = "status_code"
        case isRetryable = "is_retryable"
    }
}

enum AnyCodableValue: Codable, Hashable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case dictionary([String: AnyCodableValue])
    case array([AnyCodableValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: AnyCodableValue].self) {
            self = .dictionary(value)
        } else if let value = try? container.decode([AnyCodableValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .dictionary(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}
