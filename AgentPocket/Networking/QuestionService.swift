import Foundation

struct QuestionService: Sendable {
    let client: HTTPClient

    func list() async throws -> [QuestionRequest] {
        try await client.get(path: "/question")
    }

    func reply(id: String, answers: [String]) async throws -> Bool {
        let response: APIBoolResponse = try await client.post(path: "/question/\(id)/reply", body: QuestionReplyRequest(answers: answers))
        return response.value
    }

    func reject(id: String) async throws -> Bool {
        let response: APIBoolResponse = try await client.post(path: "/question/\(id)/reject", body: EmptyBody())
        return response.value
    }
}

private struct QuestionReplyRequest: Encodable {
    var answers: [String]
}
