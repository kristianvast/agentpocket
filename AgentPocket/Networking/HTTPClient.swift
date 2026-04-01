import Foundation

enum OpenCodeError: Error {
    case httpError(statusCode: Int, body: String?)
    case networkError(Error)
    case decodingError(Error)
    case invalidURL
}

struct EmptyBody: Encodable, Sendable {
    init() {}
}

struct EmptyResponse: Decodable, Sendable {
    init() {}
}

struct APIBoolResponse: Decodable, Sendable {
    let value: Bool

    init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(), let bool = try? single.decode(Bool.self) {
            self.value = bool
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.value =
            (try container.decodeIfPresent(Bool.self, forKey: .value))
            ?? (try container.decodeIfPresent(Bool.self, forKey: .success))
            ?? (try container.decodeIfPresent(Bool.self, forKey: .ok))
            ?? (try container.decodeIfPresent(Bool.self, forKey: .result))
            ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case value
        case success
        case ok
        case result
    }
}

struct HTTPClient: Sendable {
    let baseURL: String
    let authorizationHeader: String?
    let session: URLSession

    init(baseURL: String, authorizationHeader: String? = nil, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.authorizationHeader = authorizationHeader
        self.session = session
    }

    func get<T: Decodable>(path: String, queryItems: [URLQueryItem]? = nil) async throws -> T {
        let request = try makeRequest(path: path, method: "GET", queryItems: queryItems)
        return try await execute(request)
    }

    func post<T: Decodable, B: Encodable>(path: String, body: B) async throws -> T {
        let request = try makeRequest(path: path, method: "POST", body: body)
        return try await execute(request)
    }

    func patch<T: Decodable, B: Encodable>(path: String, body: B) async throws -> T {
        let request = try makeRequest(path: path, method: "PATCH", body: body)
        return try await execute(request)
    }

    func put<T: Decodable, B: Encodable>(path: String, body: B) async throws -> T {
        let request = try makeRequest(path: path, method: "PUT", body: body)
        return try await execute(request)
    }

    func delete<T: Decodable>(path: String) async throws -> T {
        let request = try makeRequest(path: path, method: "DELETE")
        return try await execute(request)
    }

    func postStreaming<B: Encodable>(path: String, body: B) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try makeRequest(path: path, method: "POST", body: body)
                    let (bytes, response) = try await session.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw OpenCodeError.networkError(URLError(.badServerResponse))
                    }

                    guard (200...299).contains(httpResponse.statusCode) else {
                        var bodyText: String?
                        for try await line in bytes.lines {
                            bodyText = (bodyText ?? "") + line
                        }
                        throw OpenCodeError.httpError(statusCode: httpResponse.statusCode, body: bodyText)
                    }

                    for try await line in bytes.lines {
                        if Task.isCancelled {
                            break
                        }
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
            throw OpenCodeError.invalidURL
        }

        let normalizedPath: String
        if path.hasPrefix("/") {
            normalizedPath = path
        } else {
            normalizedPath = "/" + path
        }

        if components.path.isEmpty {
            components.path = normalizedPath
        } else {
            components.path = components.path.hasSuffix("/")
                ? String(components.path.dropLast()) + normalizedPath
                : components.path + normalizedPath
        }

        components.queryItems = queryItems?.isEmpty == true ? nil : queryItems

        guard let url = components.url else {
            throw OpenCodeError.invalidURL
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
                throw OpenCodeError.networkError(URLError(.badServerResponse))
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let body = String(data: data, encoding: .utf8)
                throw OpenCodeError.httpError(statusCode: httpResponse.statusCode, body: body)
            }

            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let payload = data.isEmpty ? Data("{}".utf8) : data
                return try decoder.decode(T.self, from: payload)
            } catch {
                throw OpenCodeError.decodingError(error)
            }
        } catch {
            throw mapError(error)
        }
    }

    private func mapError(_ error: Error) -> Error {
        if error is OpenCodeError {
            return error
        }
        return OpenCodeError.networkError(error)
    }
}
