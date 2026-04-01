import Foundation
import Observation

@MainActor
@Observable
final class EventStream {
    let baseURL: String
    let authHeader: String?
    private(set) var isConnected = false

    private let session: URLSession

    init(baseURL: String, authorizationHeader: String? = nil, session: URLSession? = nil) {
        self.baseURL = baseURL
        self.authHeader = authorizationHeader
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 15
            configuration.timeoutIntervalForResource = 15
            self.session = URLSession(configuration: configuration)
        }
    }

    func events() -> AsyncThrowingStream<OpenCodeEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var backoffNanoseconds: UInt64 = 500_000_000
                let maxBackoff: UInt64 = 30_000_000_000

                while !Task.isCancelled {
                    do {
                        try await consumeSingleConnection(continuation: continuation)
                        backoffNanoseconds = 500_000_000
                    } catch is CancellationError {
                        break
                    } catch {
                        await MainActor.run {
                            self.isConnected = false
                        }
                        try? await Task.sleep(nanoseconds: backoffNanoseconds)
                        backoffNanoseconds = min(backoffNanoseconds * 2, maxBackoff)
                    }
                }

                await MainActor.run {
                    self.isConnected = false
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func consumeSingleConnection(continuation: AsyncThrowingStream<OpenCodeEvent, Error>.Continuation) async throws {
        let request = try makeRequest()
        let (bytes, response) = try await session.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenCodeError.networkError(URLError(.badServerResponse))
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw OpenCodeError.httpError(statusCode: httpResponse.statusCode, body: nil)
        }

        isConnected = true

        var bufferedDataLines: [String] = []
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        for try await line in bytes.lines {
            if Task.isCancelled {
                throw CancellationError()
            }

            if line.isEmpty {
                if !bufferedDataLines.isEmpty {
                    let payload = bufferedDataLines.joined(separator: "\n")
                    bufferedDataLines.removeAll(keepingCapacity: true)
                    if let data = payload.data(using: .utf8) {
                        let serverEvent = try decoder.decode(ServerEvent.self, from: data)
                        let event = try mapEvent(from: serverEvent, rawData: data, decoder: decoder)
                        continuation.yield(event)
                    }
                }
                continue
            }

            if line.hasPrefix("data:") {
                let value = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                bufferedDataLines.append(value)
            }
        }

        isConnected = false
    }

    private func makeRequest() throws -> URLRequest {
        guard var components = URLComponents(string: baseURL) else {
            throw OpenCodeError.invalidURL
        }

        let eventPath = "/event"
        if components.path.isEmpty {
            components.path = eventPath
        } else {
            components.path = components.path.hasSuffix("/") ? String(components.path.dropLast()) + eventPath : components.path + eventPath
        }

        guard let url = components.url else {
            throw OpenCodeError.invalidURL
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

    private func mapEvent(from serverEvent: ServerEvent, rawData: Data, decoder: JSONDecoder) throws -> OpenCodeEvent {
        switch serverEvent.type {
        default:
            return try decoder.decode(OpenCodeEvent.self, from: rawData)
        }
    }
}

private struct ServerEvent: Decodable {
    let type: String
}
