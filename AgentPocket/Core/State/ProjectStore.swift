import Foundation
import Observation

@MainActor
@Observable
final class ProjectStore {
    var projects: [Project] = []
    var activeProjectID: ProjectID?
    var isLoading = false

    var activeProject: Project? {
        guard let id = activeProjectID else { return nil }
        return projects.first { $0.id == id }
    }

    var sortedProjects: [Project] {
        projects.sorted { a, b in
            a.time.updated > b.time.updated
        }
    }

    func setProjects(_ newProjects: [Project]) {
        projects = newProjects
    }

    func updateProject(_ project: Project) {
        if let idx = projects.firstIndex(where: { $0.id == project.id }) {
            projects[idx] = project
        }
    }

    func clear() {
        projects = []
        activeProjectID = nil
        isLoading = false
    }
}
