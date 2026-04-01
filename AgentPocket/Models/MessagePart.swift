import Foundation

typealias PartID = String

struct MessagePart: Codable, Identifiable, Hashable, Sendable {
    let id: PartID
    var messageID: MessageID
    var type: PartType
    var content: PartContent

    enum CodingKeys: String, CodingKey {
        case id
        case messageID = "message_id"
        case type
        case content
    }

    init(id: PartID, messageID: MessageID, type: PartType, content: PartContent) {
        self.id = id
        self.messageID = messageID
        self.type = type
        self.content = content
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(PartID.self, forKey: .id)
        messageID = try container.decode(MessageID.self, forKey: .messageID)
        type = try container.decode(PartType.self, forKey: .type)

        let payloadDecoder: Decoder
        if container.contains(.content) {
            payloadDecoder = try container.superDecoder(forKey: .content)
        } else {
            payloadDecoder = decoder
        }

        switch type {
        case .text:
            content = .text(try TextPartData(from: payloadDecoder))
        case .reasoning:
            content = .reasoning(try ReasoningPartData(from: payloadDecoder))
        case .file:
            content = .file(try FilePartData(from: payloadDecoder))
        case .tool:
            content = .tool(try ToolPartData(from: payloadDecoder))
        case .stepStart:
            content = .stepStart(try StepStartData(from: payloadDecoder))
        case .stepFinish:
            content = .stepFinish(try StepFinishData(from: payloadDecoder))
        case .snapshot:
            content = .snapshot(try SnapshotPartData(from: payloadDecoder))
        case .patch:
            content = .patch(try PatchPartData(from: payloadDecoder))
        case .agent:
            content = .agent(try AgentPartData(from: payloadDecoder))
        case .retry:
            content = .retry(try RetryPartData(from: payloadDecoder))
        case .compaction:
            content = .compaction(try CompactionPartData(from: payloadDecoder))
        case .subtask:
            content = .subtask(try SubtaskPartData(from: payloadDecoder))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(messageID, forKey: .messageID)
        try container.encode(type, forKey: .type)
        try container.encode(content, forKey: .content)
    }
}

enum PartType: String, Codable, Hashable, Sendable {
    case text
    case reasoning
    case file
    case tool
    case stepStart = "step-start"
    case stepFinish = "step-finish"
    case snapshot
    case patch
    case agent
    case retry
    case compaction
    case subtask
}

enum PartContent: Codable, Hashable, Sendable {
    case text(TextPartData)
    case reasoning(ReasoningPartData)
    case file(FilePartData)
    case tool(ToolPartData)
    case stepStart(StepStartData)
    case stepFinish(StepFinishData)
    case snapshot(SnapshotPartData)
    case patch(PatchPartData)
    case agent(AgentPartData)
    case retry(RetryPartData)
    case compaction(CompactionPartData)
    case subtask(SubtaskPartData)
    case unknown

    init(from decoder: Decoder) throws {
        if let value = try? TextPartData(from: decoder) {
            self = .text(value)
        } else if let value = try? ReasoningPartData(from: decoder) {
            self = .reasoning(value)
        } else if let value = try? FilePartData(from: decoder) {
            self = .file(value)
        } else if let value = try? ToolPartData(from: decoder) {
            self = .tool(value)
        } else if let value = try? StepStartData(from: decoder) {
            self = .stepStart(value)
        } else if let value = try? StepFinishData(from: decoder) {
            self = .stepFinish(value)
        } else if let value = try? SnapshotPartData(from: decoder) {
            self = .snapshot(value)
        } else if let value = try? PatchPartData(from: decoder) {
            self = .patch(value)
        } else if let value = try? AgentPartData(from: decoder) {
            self = .agent(value)
        } else if let value = try? RetryPartData(from: decoder) {
            self = .retry(value)
        } else if let value = try? CompactionPartData(from: decoder) {
            self = .compaction(value)
        } else if let value = try? SubtaskPartData(from: decoder) {
            self = .subtask(value)
        } else {
            self = .unknown
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let value):
            try value.encode(to: encoder)
        case .reasoning(let value):
            try value.encode(to: encoder)
        case .file(let value):
            try value.encode(to: encoder)
        case .tool(let value):
            try value.encode(to: encoder)
        case .stepStart(let value):
            try value.encode(to: encoder)
        case .stepFinish(let value):
            try value.encode(to: encoder)
        case .snapshot(let value):
            try value.encode(to: encoder)
        case .patch(let value):
            try value.encode(to: encoder)
        case .agent(let value):
            try value.encode(to: encoder)
        case .retry(let value):
            try value.encode(to: encoder)
        case .compaction(let value):
            try value.encode(to: encoder)
        case .subtask(let value):
            try value.encode(to: encoder)
        case .unknown:
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        }
    }
}

struct TextPartData: Codable, Hashable, Sendable {
    var text: String
    var delta: String?
}

struct ReasoningPartData: Codable, Hashable, Sendable {
    var text: String
    var signature: String?
    var redacted: Bool?
    var tokens: Int?
}

struct FilePartData: Codable, Hashable, Sendable {
    var path: String
    var mimeType: String?
    var content: String?
    var language: String?
    var size: Int?

    enum CodingKeys: String, CodingKey {
        case path
        case mimeType = "mime_type"
        case content
        case language
        case size
    }
}

struct StepStartData: Codable, Hashable, Sendable {
    var title: String?
    var level: Int?
}

struct StepFinishData: Codable, Hashable, Sendable {
    var summary: String?
    var status: String?
}

struct SnapshotPartData: Codable, Hashable, Sendable {
    var message: String?
    var files: [FileDiff]?
}

struct PatchPartData: Codable, Hashable, Sendable {
    var patch: String?
    var files: [FileDiff]?
    var additions: Int?
    var deletions: Int?
}

struct AgentPartData: Codable, Hashable, Sendable {
    var name: String
    var model: ModelReference?
    var sessionID: SessionID?

    enum CodingKeys: String, CodingKey {
        case name
        case model
        case sessionID = "session_id"
    }
}

struct RetryPartData: Codable, Hashable, Sendable {
    var attempt: Int
    var reason: String?
    var next: Double?
}

struct CompactionPartData: Codable, Hashable, Sendable {
    var summary: String?
    var before: Int?
    var after: Int?
}

struct SubtaskPartData: Codable, Hashable, Sendable {
    var id: String?
    var title: String
    var status: String?
    var sessionID: SessionID?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case status
        case sessionID = "session_id"
    }
}
