import Foundation

struct FileService: Sendable {
    let client: HTTPClient

    func list(path: String) async throws -> [FileNode] {
        try await client.get(path: "/file", queryItems: [URLQueryItem(name: "path", value: path)])
    }

    func read(path: String) async throws -> FileContent {
        try await client.get(path: "/file/read", queryItems: [URLQueryItem(name: "path", value: path)])
    }

    func status() async throws -> [FileInfo] {
        try await client.get(path: "/file/status")
    }

    func findText(pattern: String) async throws -> [SearchMatch] {
        try await client.post(path: "/file/find/text", body: FindTextRequest(pattern: pattern))
    }

    func findFiles(query: String, limit: Int?) async throws -> [String] {
        var items: [URLQueryItem] = [URLQueryItem(name: "query", value: query)]
        if let limit { items.append(URLQueryItem(name: "limit", value: String(limit))) }
        return try await client.get(path: "/file/find/files", queryItems: items)
    }

    func findSymbols(query: String) async throws -> [SymbolMatch] {
        try await client.get(path: "/file/find/symbols", queryItems: [URLQueryItem(name: "query", value: query)])
    }
}

struct SearchMatch: Codable, Hashable {
    var path: String
    var line: Int?
    var text: String?
    var matchStart: Int?
    var matchEnd: Int?
}

struct SymbolMatch: Codable, Hashable {
    var name: String
    var kind: Int?
    var location: SymbolLocation?
}

struct SymbolLocation: Codable, Hashable {
    var uri: String?
    var range: SymbolRange?
}

struct SymbolRange: Codable, Hashable {
    var start: SymbolPosition
    var end: SymbolPosition
}

struct SymbolPosition: Codable, Hashable {
    var line: Int
    var character: Int
}

private struct FindTextRequest: Encodable {
    var pattern: String
}
