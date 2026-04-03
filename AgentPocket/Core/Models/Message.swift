import Foundation

// MARK: - Message

struct Message: Codable, Identifiable, Hashable, Sendable {
    let id: MessageID
    var conversationID: ConversationID
    var role: MessageRole
    var content: [MessageContent]
    var createdAt: Date
    var metadata: MessageMetadata

    init(
        id: MessageID,
        conversationID: ConversationID,
        role: MessageRole,
        content: [MessageContent],
        createdAt: Date = .now,
        metadata: MessageMetadata = MessageMetadata()
    ) {
        self.id = id
        self.conversationID = conversationID
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.metadata = metadata
    }
}

// MARK: - Role

enum MessageRole: String, Codable, Hashable, Sendable {
    case user
    case assistant
    case system
}

// MARK: - Message Content

struct MessageContent: Codable, Identifiable, Hashable, Sendable {
    let id: ContentID
    var type: ContentType
    var data: ContentData

    init(id: ContentID = UUID().uuidString, type: ContentType, data: ContentData) {
        self.id = id
        self.type = type
        self.data = data
    }
}

enum ContentType: String, Codable, Hashable, Sendable {
    case text
    case audio
    case image
    case file
    case tool
    case reasoning
    case error
}

// MARK: - Content Data

enum ContentData: Codable, Hashable, Sendable {
    case text(TextContent)
    case audio(AudioContent)
    case image(ImageContent)
    case file(FileContent)
    case tool(ToolContent)
    case reasoning(ReasoningContent)
    case error(ErrorContent)

    // Convenience initializers
    static func plainText(_ text: String) -> ContentData {
        .text(TextContent(text: text))
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case type, payload
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ContentType.self, forKey: .type)
        switch type {
        case .text:
            self = .text(try container.decode(TextContent.self, forKey: .payload))
        case .audio:
            self = .audio(try container.decode(AudioContent.self, forKey: .payload))
        case .image:
            self = .image(try container.decode(ImageContent.self, forKey: .payload))
        case .file:
            self = .file(try container.decode(FileContent.self, forKey: .payload))
        case .tool:
            self = .tool(try container.decode(ToolContent.self, forKey: .payload))
        case .reasoning:
            self = .reasoning(try container.decode(ReasoningContent.self, forKey: .payload))
        case .error:
            self = .error(try container.decode(ErrorContent.self, forKey: .payload))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let v):
            try container.encode(ContentType.text, forKey: .type)
            try container.encode(v, forKey: .payload)
        case .audio(let v):
            try container.encode(ContentType.audio, forKey: .type)
            try container.encode(v, forKey: .payload)
        case .image(let v):
            try container.encode(ContentType.image, forKey: .type)
            try container.encode(v, forKey: .payload)
        case .file(let v):
            try container.encode(ContentType.file, forKey: .type)
            try container.encode(v, forKey: .payload)
        case .tool(let v):
            try container.encode(ContentType.tool, forKey: .type)
            try container.encode(v, forKey: .payload)
        case .reasoning(let v):
            try container.encode(ContentType.reasoning, forKey: .type)
            try container.encode(v, forKey: .payload)
        case .error(let v):
            try container.encode(ContentType.error, forKey: .type)
            try container.encode(v, forKey: .payload)
        }
    }
}

// MARK: - Content Payloads

struct TextContent: Codable, Hashable, Sendable {
    var text: String
}

struct AudioContent: Codable, Hashable, Sendable {
    var data: Data?
    var url: String?
    var mimeType: String
    var duration: TimeInterval?
    var transcript: String?

    init(data: Data? = nil, url: String? = nil, mimeType: String = "audio/wav", duration: TimeInterval? = nil, transcript: String? = nil) {
        self.data = data
        self.url = url
        self.mimeType = mimeType
        self.duration = duration
        self.transcript = transcript
    }
}

struct ImageContent: Codable, Hashable, Sendable {
    var data: Data?
    var url: String?
    var mimeType: String
    var width: Int?
    var height: Int?
    var caption: String?

    init(data: Data? = nil, url: String? = nil, mimeType: String = "image/jpeg", width: Int? = nil, height: Int? = nil, caption: String? = nil) {
        self.data = data
        self.url = url
        self.mimeType = mimeType
        self.width = width
        self.height = height
        self.caption = caption
    }
}

struct FileContent: Codable, Hashable, Sendable {
    var path: String
    var mimeType: String?
    var content: String?
    var language: String?
    var size: Int?
}

struct ToolContent: Codable, Hashable, Sendable {
    var toolID: ToolID
    var name: String
    var status: ToolStatus
    var input: String?
    var output: String?
    var error: String?
    var duration: TimeInterval?
}

enum ToolStatus: String, Codable, Hashable, Sendable {
    case pending
    case running
    case completed
    case failed
}

struct ReasoningContent: Codable, Hashable, Sendable {
    var text: String
    var isRedacted: Bool
    var tokenCount: Int?

    init(text: String, isRedacted: Bool = false, tokenCount: Int? = nil) {
        self.text = text
        self.isRedacted = isRedacted
        self.tokenCount = tokenCount
    }
}

struct ErrorContent: Codable, Hashable, Sendable {
    var name: String
    var message: String
    var isRetryable: Bool

    init(name: String, message: String, isRetryable: Bool = false) {
        self.name = name
        self.message = message
        self.isRetryable = isRetryable
    }
}

// MARK: - Message Metadata

struct MessageMetadata: Codable, Hashable, Sendable {
    var agentName: String?
    var modelID: String?
    var providerID: String?
    var inputTokens: Int?
    var outputTokens: Int?
    var cost: Double?
    var finishReason: String?

    init(
        agentName: String? = nil,
        modelID: String? = nil,
        providerID: String? = nil,
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        cost: Double? = nil,
        finishReason: String? = nil
    ) {
        self.agentName = agentName
        self.modelID = modelID
        self.providerID = providerID
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cost = cost
        self.finishReason = finishReason
    }
}
