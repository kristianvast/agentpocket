import Foundation

struct FileInfo: Codable, Hashable, Sendable {
    var path: String
    var status: FileChangeStatus
    var added: Int
    var removed: Int
}

enum FileChangeStatus: String, Codable, Hashable, Sendable {
    case added
    case deleted
    case modified
}

struct FileNode: Codable, Identifiable, Hashable, Sendable {
    var id: String { path }
    var name: String
    var path: String
    var absolute: String?
    var type: FileNodeType
    var ignored: Bool?
}

enum FileNodeType: String, Codable, Hashable, Sendable {
    case file
    case directory
}

struct FileContent: Codable, Hashable, Sendable {
    var type: String
    var content: String
    var diff: String?
    var patch: FilePatch?
    var encoding: String?
    var mimeType: String?

    enum CodingKeys: String, CodingKey {
        case type
        case content
        case diff
        case patch
        case encoding
        case mimeType = "mime_type"
    }
}

struct FilePatch: Codable, Hashable, Sendable {
    var oldPath: String?
    var newPath: String?
    var hunks: [FilePatchHunk]

    enum CodingKeys: String, CodingKey {
        case oldPath = "old_path"
        case newPath = "new_path"
        case hunks
    }
}

struct FilePatchHunk: Codable, Hashable, Sendable {
    var oldStart: Int
    var oldLines: Int
    var newStart: Int
    var newLines: Int
    var lines: [String]

    enum CodingKeys: String, CodingKey {
        case oldStart = "old_start"
        case oldLines = "old_lines"
        case newStart = "new_start"
        case newLines = "new_lines"
        case lines
    }
}

struct FileDiff: Codable, Hashable, Sendable {
    var file: String
    var before: String?
    var after: String?
    var additions: Int
    var deletions: Int
    var status: FileChangeStatus
}
