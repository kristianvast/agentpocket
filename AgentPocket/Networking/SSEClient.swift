import Foundation

final class SSEClient: Sendable {
    let baseURL: String
    let path: String
    let authHeader: String?
    let maxRetries: Int
    private let session: URLSession

    init(baseURL: String, path: String, authorizationHeader: String? = nil, maxRetries: Int = 10) {
        self.baseURL = baseURL
        self.path = path
        self.authHeader = authorizationHeader
        self.maxRetries = maxRetries

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
                var lastEventID: String?
                var retryCount = 0

                while !Task.isCancelled && retryCount < maxRetries {
                    do {
                        lastEventID = try await consumeConnection(continuation: continuation, lastEventID: lastEventID)
                        backoffNanoseconds = 500_000_000
                        retryCount = 0
                    } catch is CancellationError {
                        break
                    } catch {
                        retryCount += 1
                        let jitteredNanoseconds = UInt64(Double(backoffNanoseconds) * Double.random(in: 0.5...1.5))
                        try? await Task.sleep(nanoseconds: jitteredNanoseconds)
                        backoffNanoseconds = min(backoffNanoseconds * 2, maxBackoff)
                    }
                }

                if retryCount >= maxRetries && !Task.isCancelled {
                    continuation.finish(throwing: AgentPocketError.networkError(NSError(domain: "SSEClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Max reconnection attempts exhausted"])))
                } else {
                    continuation.finish()
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func consumeConnection(continuation: AsyncThrowingStream<SSEEvent, Error>.Continuation, lastEventID: String?) async throws -> String? {
        let request = try makeRequest(lastEventID: lastEventID)
        let (bytes, response) = try await session.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AgentPocketError.networkError(URLError(.badServerResponse))
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw AgentPocketError.serverError(statusCode: httpResponse.statusCode, message: nil)
        }

        var eventType: String?
        var dataLines: [String] = []
        var currentEventID = lastEventID

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
            } else if line.hasPrefix("id:") {
                currentEventID = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            }
        }

        return currentEventID
    }

    private func makeRequest(lastEventID: String? = nil) throws -> URLRequest {
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
        if let lastEventID {
            request.setValue(lastEventID, forHTTPHeaderField: "Last-Event-ID")
        }
        return request
    }
}

struct SSEEvent: Sendable {
    let type: String?
    let data: String
    let rawData: Data
}
