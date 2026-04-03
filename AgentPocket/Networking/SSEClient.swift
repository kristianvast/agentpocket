import Foundation

final class SSEClient: Sendable {
    let baseURL: String
    let path: String
    let authHeader: String?
    private let session: URLSession

    init(baseURL: String, path: String, authorizationHeader: String? = nil) {
        self.baseURL = baseURL
        self.path = path
        self.authHeader = authorizationHeader

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 300
        configuration.timeoutIntervalForResource = 0
        self.session = URLSession(configuration: configuration)
    }

    func events() -> AsyncThrowingStream<SSEEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var backoffNanoseconds: UInt64 = 500_000_000
                let maxBackoff: UInt64 = 30_000_000_000

                while !Task.isCancelled {
                    do {
                        try await consumeConnection(continuation: continuation)
                        backoffNanoseconds = 500_000_000
                    } catch is CancellationError {
                        break
                    } catch {
                        try? await Task.sleep(nanoseconds: backoffNanoseconds)
                        backoffNanoseconds = min(backoffNanoseconds * 2, maxBackoff)
                    }
                }

                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func consumeConnection(continuation: AsyncThrowingStream<SSEEvent, Error>.Continuation) async throws {
        let request = try makeRequest()
        let (bytes, response) = try await session.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AgentPocketError.networkError(URLError(.badServerResponse))
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw AgentPocketError.serverError(statusCode: httpResponse.statusCode, message: nil)
        }

        var eventType: String?
        var dataLines: [String] = []

        for try await line in bytes.lines {
            if Task.isCancelled { throw CancellationError() }

            if line.isEmpty {
                if !dataLines.isEmpty {
                    let payload = dataLines.joined(separator: "\n")
                    let event = SSEEvent(
                        type: eventType,
                        data: payload,
                        rawData: Data(payload.utf8)
                    )
                    continuation.yield(event)
                    dataLines.removeAll(keepingCapacity: true)
                    eventType = nil
                }
                continue
            }

            if line.hasPrefix("data:") {
                let value = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                dataLines.append(value)
            } else if line.hasPrefix("event:") {
                eventType = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            }
        }
    }

    private func makeRequest() throws -> URLRequest {
        guard var components = URLComponents(string: baseURL) else {
            throw AgentPocketError.invalidURL
        }

        let normalizedPath = path.hasPrefix("/") ? path : "/\(path)"
        if components.path.isEmpty {
            components.path = normalizedPath
        } else {
            let base = components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path
            components.path = base + normalizedPath
        }

        guard let url = components.url else {
            throw AgentPocketError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        if let authHeader {
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        }
        return request
    }
}

struct SSEEvent: Sendable {
    let type: String?
    let data: String
    let rawData: Data
}
