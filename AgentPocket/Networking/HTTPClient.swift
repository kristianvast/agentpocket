import Foundation

struct HTTPClient: Sendable {
    let baseURL: String
    let authorizationHeader: String?
    nonisolated(unsafe) let session: URLSession

    init(baseURL: String, authorizationHeader: String? = nil, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.authorizationHeader = authorizationHeader
        self.session = session
    }

    func get<T: Decodable & Sendable>(path: String, queryItems: [URLQueryItem]? = nil) async throws -> T {
        let request = try makeRequest(path: path, method: "GET", queryItems: queryItems)
        return try await execute(request)
    }

    func post<T: Decodable & Sendable, B: Encodable & Sendable>(path: String, body: B) async throws -> T {
        let request = try makeRequest(path: path, method: "POST", body: body)
        return try await execute(request)
    }

    func patch<T: Decodable & Sendable, B: Encodable & Sendable>(path: String, body: B) async throws -> T {
        let request = try makeRequest(path: path, method: "PATCH", body: body)
        return try await execute(request)
    }

    func put<T: Decodable & Sendable, B: Encodable & Sendable>(path: String, body: B) async throws -> T {
        let request = try makeRequest(path: path, method: "PUT", body: body)
        return try await execute(request)
    }

    func delete<T: Decodable & Sendable>(path: String) async throws -> T {
        let request = try makeRequest(path: path, method: "DELETE")
        return try await execute(request)
    }

    func postStreaming<B: Encodable & Sendable>(path: String, body: B) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try makeRequest(path: path, method: "POST", body: body)
                    let (bytes, response) = try await session.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw AgentPocketError.networkError(URLError(.badServerResponse))
                    }

                    guard (200...299).contains(httpResponse.statusCode) else {
                        var bodyText: String?
                        for try await line in bytes.lines {
                            bodyText = (bodyText ?? "") + line
                        }
                        throw AgentPocketError.serverError(statusCode: httpResponse.statusCode, message: bodyText)
                    }

                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        let data = Data(line.utf8)
                        continuation.yield(data)
                    }

                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: mapError(error))
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func makeRequest(path: String, method: String, queryItems: [URLQueryItem]? = nil) throws -> URLRequest {
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

        components.queryItems = queryItems?.isEmpty == true ? nil : queryItems

        guard let url = components.url else {
            throw AgentPocketError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let authorizationHeader {
            request.setValue(authorizationHeader, forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func makeRequest<B: Encodable>(path: String, method: String, body: B, queryItems: [URLQueryItem]? = nil) throws -> URLRequest {
        var request = try makeRequest(path: path, method: method, queryItems: queryItems)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(body)
        return request
    }

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AgentPocketError.networkError(URLError(.badServerResponse))
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let body = String(data: data, encoding: .utf8)
                throw AgentPocketError.serverError(statusCode: httpResponse.statusCode, message: body)
            }

            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let payload = data.isEmpty ? Data("{}".utf8) : data
                return try decoder.decode(T.self, from: payload)
            } catch {
                throw AgentPocketError.decodingError(error)
            }
        } catch let error as AgentPocketError {
            throw error
        } catch {
            throw AgentPocketError.networkError(error)
        }
    }

    private func mapError(_ error: Error) -> Error {
        if error is AgentPocketError { return error }
        return AgentPocketError.networkError(error)
    }
}

struct EmptyBody: Encodable, Sendable {}
struct EmptyResponse: Decodable, Sendable {}
