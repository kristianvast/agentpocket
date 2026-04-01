import Foundation

struct PTYService: Sendable {
    let client: HTTPClient

    func list() async throws -> [PtyInfo] {
        try await client.get(path: "/pty")
    }

    func create(command: String?, args: [String]?, cwd: String?, title: String?) async throws -> PtyInfo {
        try await client.post(path: "/pty", body: CreatePTYRequest(command: command, args: args, cwd: cwd, title: title))
    }

    func get(id: PtyID) async throws -> PtyInfo {
        try await client.get(path: "/pty/\(id)")
    }

    func update(id: PtyID, title: String?, size: PtySize?) async throws -> PtyInfo {
        try await client.patch(path: "/pty/\(id)", body: UpdatePTYRequest(title: title, size: size))
    }

    func remove(id: PtyID) async throws -> Bool {
        let response: APIBoolResponse = try await client.delete(path: "/pty/\(id)")
        return response.value
    }
}

private struct CreatePTYRequest: Encodable {
    var command: String?
    var args: [String]?
    var cwd: String?
    var title: String?
}

private struct UpdatePTYRequest: Encodable {
    var title: String?
    var size: PtySize?
}
