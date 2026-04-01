import Foundation

struct SessionService: Sendable {
    let client: HTTPClient

    func list(directory: String? = nil, search: String? = nil, limit: Int? = nil) async throws -> [Session] {
        var items: [URLQueryItem] = []
        if let directory { items.append(URLQueryItem(name: "directory", value: directory)) }
        if let search { items.append(URLQueryItem(name: "search", value: search)) }
        if let limit { items.append(URLQueryItem(name: "limit", value: String(limit))) }
        return try await client.get(path: "/session", queryItems: items.isEmpty ? nil : items)
    }

    func get(id: SessionID) async throws -> Session {
        try await client.get(path: "/session/\(id)")
    }

    func create() async throws -> Session {
        try await client.post(path: "/session", body: EmptyBody())
    }

    func update(id: SessionID, title: String?, archived: Double?) async throws -> Session {
        try await client.patch(path: "/session/\(id)", body: UpdateSessionRequest(title: title, archived: archived))
    }

    func delete(id: SessionID) async throws -> Bool {
        let response: APIBoolResponse = try await client.delete(path: "/session/\(id)")
        return response.value
    }

    func status() async throws -> [String: SessionStatus] {
        try await client.get(path: "/session/status")
    }

    func children(id: SessionID) async throws -> [Session] {
        try await client.get(path: "/session/\(id)/children")
    }

    func messages(id: SessionID, limit: Int? = nil, before: String? = nil) async throws -> [MessageWithParts] {
        var items: [URLQueryItem] = []
        if let limit { items.append(URLQueryItem(name: "limit", value: String(limit))) }
        if let before { items.append(URLQueryItem(name: "before", value: before)) }
        return try await client.get(path: "/session/\(id)/message", queryItems: items.isEmpty ? nil : items)
    }

    func message(sessionID: SessionID, messageID: MessageID) async throws -> MessageWithParts {
        try await client.get(path: "/session/\(sessionID)/message/\(messageID)")
    }

    func sendMessage(sessionID: SessionID, parts: [PromptPart], model: ModelReference?, agent: String?) -> AsyncThrowingStream<Data, Error> {
        let body = SendMessageRequest(parts: parts, model: model, agent: agent)
        return client.postStreaming(path: "/session/\(sessionID)/message", body: body)
    }

    func abort(id: SessionID) async throws -> Bool {
        let response: APIBoolResponse = try await client.post(path: "/session/\(id)/abort", body: EmptyBody())
        return response.value
    }

    func fork(id: SessionID, messageID: MessageID?) async throws -> Session {
        try await client.post(path: "/session/\(id)/fork", body: ForkRequest(messageID: messageID))
    }

    func revert(id: SessionID, messageID: MessageID) async throws -> Session {
        try await client.post(path: "/session/\(id)/revert", body: RevertRequest(messageID: messageID))
    }

    func unrevert(id: SessionID) async throws -> Session {
        try await client.post(path: "/session/\(id)/unrevert", body: EmptyBody())
    }

    func share(id: SessionID) async throws -> Session {
        try await client.post(path: "/session/\(id)/share", body: EmptyBody())
    }

    func unshare(id: SessionID) async throws -> Session {
        try await client.post(path: "/session/\(id)/unshare", body: EmptyBody())
    }

    func diff(id: SessionID, messageID: MessageID) async throws -> [FileDiff] {
        try await client.get(path: "/session/\(id)/diff/\(messageID)")
    }

    func todos(id: SessionID) async throws -> [Todo] {
        try await client.get(path: "/session/\(id)/todo")
    }

    func summarize(id: SessionID, providerID: String, modelID: String) async throws -> Bool {
        let response: APIBoolResponse = try await client.post(path: "/session/\(id)/summarize", body: SummarizeRequest(providerID: providerID, modelID: modelID))
        return response.value
    }
}

struct MessageWithParts: Codable, Identifiable, Hashable {
    var id: MessageID { info.id }
    var info: Message
    var parts: [MessagePart]
}

struct PromptPart: Codable {
    var type: String
    var text: String?
    var file: PromptFileSource?
}

struct PromptFileSource: Codable {
    var path: String?
    var url: String?
}

private struct UpdateSessionRequest: Encodable {
    var title: String?
    var archived: Double?
}

private struct SendMessageRequest: Encodable {
    var parts: [PromptPart]
    var model: ModelReference?
    var agent: String?
}

private struct ForkRequest: Encodable {
    var messageID: MessageID?
}

private struct RevertRequest: Encodable {
    var messageID: MessageID
}

private struct SummarizeRequest: Encodable {
    var providerID: String
    var modelID: String
}
