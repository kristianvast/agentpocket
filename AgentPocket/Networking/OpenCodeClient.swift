import Foundation

@MainActor
final class OpenCodeClient {
    let sessions: SessionService
    let files: FileService
    let pty: PTYService
    let providers: ProviderService
    let config: ConfigService
    let permissions: PermissionService
    let questions: QuestionService
    let mcp: MCPService
    let eventStream: EventStream

    private let httpClient: HTTPClient

    init(baseURL: String, authorization: String? = nil) {
        let httpClient = HTTPClient(baseURL: baseURL, authorizationHeader: authorization)
        self.httpClient = httpClient
        self.sessions = SessionService(client: httpClient)
        self.files = FileService(client: httpClient)
        self.pty = PTYService(client: httpClient)
        self.providers = ProviderService(client: httpClient)
        self.config = ConfigService(client: httpClient)
        self.permissions = PermissionService(client: httpClient)
        self.questions = QuestionService(client: httpClient)
        self.mcp = MCPService(client: httpClient)
        self.eventStream = EventStream(baseURL: baseURL, authorizationHeader: authorization)
    }

    func checkHealth() async throws -> HealthResponse {
        try await httpClient.get(path: "/health")
    }

    func createPTYWebSocket(ptyID: PtyID) -> PTYWebSocket {
        PTYWebSocket(baseURL: httpClient.baseURL, ptyID: ptyID, authorization: httpClient.authorizationHeader)
    }

    func agents() async throws -> [AgentInfo] {
        try await httpClient.get(path: "/agent")
    }

    func skills() async throws -> [SkillInfo] {
        try await httpClient.get(path: "/skill")
    }

    func commands() async throws -> [CommandInfo] {
        try await httpClient.get(path: "/command")
    }

    func lspStatus() async throws -> [LspStatus] {
        try await httpClient.get(path: "/lsp")
    }

    func pathInfo() async throws -> PathInfo {
        try await httpClient.get(path: "/path")
    }

    func vcsInfo() async throws -> VcsInfo {
        try await httpClient.get(path: "/vcs")
    }

    func projects() async throws -> [Project] {
        try await httpClient.get(path: "/project")
    }

    func currentProject() async throws -> Project {
        try await httpClient.get(path: "/project/current")
    }
}
