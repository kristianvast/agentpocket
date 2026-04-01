import Foundation

struct PermissionService: Sendable {
    let client: HTTPClient

    func list() async throws -> [PermissionRequest] {
        try await client.get(path: "/permission")
    }

    func reply(id: PermissionID, reply: PermissionReply) async throws -> Bool {
        let response: APIBoolResponse = try await client.post(path: "/permission/\(id)/reply", body: PermissionReplyRequest(reply: reply))
        return response.value
    }
}

private struct PermissionReplyRequest: Encodable {
    var reply: PermissionReply
}
