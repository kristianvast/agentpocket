import Foundation

// MARK: - Project

struct Project: Codable, Identifiable, Hashable, Sendable {
    let id: ProjectID
    var worktree: String
    var name: String?
    var icon: ProjectIcon?
    var time: ProjectTime
    var sessionCount: Int?

    var displayName: String {
        if let name, !name.isEmpty { return name }
        return URL(fileURLWithPath: worktree).lastPathComponent
    }

    var shortPath: String {
        let home = NSHomeDirectory()
        if worktree.hasPrefix(home) {
            return "~" + worktree.dropFirst(home.count)
        }
        return worktree
    }

    init(
        id: ProjectID,
        worktree: String,
        name: String? = nil,
        icon: ProjectIcon? = nil,
        time: ProjectTime = ProjectTime(created: .now, updated: .now),
        sessionCount: Int? = nil
    ) {
        self.id = id
        self.worktree = worktree
        self.name = name
        self.icon = icon
        self.time = time
        self.sessionCount = sessionCount
    }
}

// MARK: - Project Icon

struct ProjectIcon: Codable, Hashable, Sendable {
    var url: String?
    var color: String?
}

// MARK: - Project Time

struct ProjectTime: Codable, Hashable, Sendable {
    var created: Date
    var updated: Date
    var initialized: Date?
}

// MARK: - Session Summary

struct SessionSummary: Codable, Hashable, Sendable {
    var additions: Int
    var deletions: Int
    var files: Int

    init(additions: Int = 0, deletions: Int = 0, files: Int = 0) {
        self.additions = additions
        self.deletions = deletions
        self.files = files
    }
}
