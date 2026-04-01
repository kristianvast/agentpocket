import Foundation

enum ToolStatus: String, Codable, Hashable, Sendable {
    case pending
    case running
    case completed
    case error
}

struct ToolPartData: Codable, Hashable, Sendable {
    var callID: String
    var tool: String
    var state: ToolState

    enum CodingKeys: String, CodingKey {
        case callID = "call_id"
        case tool
        case state
    }
}

enum ToolState: Codable, Hashable, Sendable {
    case pending(ToolPendingState)
    case running(ToolRunningState)
    case completed(ToolCompletedState)
    case error(ToolErrorState)

    enum CodingKeys: String, CodingKey {
        case status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let status = try container.decode(ToolStatus.self, forKey: .status)
        switch status {
        case .pending:
            self = .pending(try ToolPendingState(from: decoder))
        case .running:
            self = .running(try ToolRunningState(from: decoder))
        case .completed:
            self = .completed(try ToolCompletedState(from: decoder))
        case .error:
            self = .error(try ToolErrorState(from: decoder))
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .pending(let state):
            try state.encode(to: encoder)
        case .running(let state):
            try state.encode(to: encoder)
        case .completed(let state):
            try state.encode(to: encoder)
        case .error(let state):
            try state.encode(to: encoder)
        }
    }
}

struct ToolPendingState: Codable, Hashable, Sendable {
    var status: ToolStatus
    var input: AnyCodableValue?
    var title: String?
    var metadata: [String: AnyCodableValue]?
    var time: Double?
    var attachments: [ToolAttachment]?
}

struct ToolRunningState: Codable, Hashable, Sendable {
    var status: ToolStatus
    var input: AnyCodableValue?
    var title: String?
    var metadata: [String: AnyCodableValue]?
    var time: Double?
    var attachments: [ToolAttachment]?
}

struct ToolCompletedState: Codable, Hashable, Sendable {
    var status: ToolStatus
    var input: AnyCodableValue?
    var output: AnyCodableValue?
    var title: String?
    var metadata: [String: AnyCodableValue]?
    var time: Double?
    var error: MessageError?
    var attachments: [ToolAttachment]?
}

struct ToolErrorState: Codable, Hashable, Sendable {
    var status: ToolStatus
    var input: AnyCodableValue?
    var output: AnyCodableValue?
    var title: String?
    var metadata: [String: AnyCodableValue]?
    var time: Double?
    var error: MessageError?
    var attachments: [ToolAttachment]?
}

struct ToolAttachment: Codable, Hashable, Identifiable, Sendable {
    var id: String { name }
    var name: String
    var type: String?
    var url: String?
    var mimeType: String?
    var size: Int?

    enum CodingKeys: String, CodingKey {
        case name
        case type
        case url
        case mimeType = "mime_type"
        case size
    }
}
