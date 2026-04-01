import Foundation

typealias PtyID = String

struct PtyInfo: Codable, Identifiable, Hashable, Sendable {
    var id: PtyID
    var title: String
    var command: String?
    var args: [String]?
    var cwd: String?
    var status: PtyStatus?
    var pid: Int?
}

enum PtyStatus: String, Codable, Hashable, Sendable {
    case running
    case exited
}

struct PtyMetadata: Codable, Sendable {
    var cursor: Int
}

struct PtyCreateRequest: Codable, Sendable {
    var command: String?
    var args: [String]?
    var cwd: String?
    var title: String?
    var env: [String: String]?
}

struct PtyResizeRequest: Codable, Sendable {
    var title: String?
    var size: PtySize?
}

struct PtySize: Codable, Hashable, Sendable {
    var rows: Int
    var cols: Int
}
