import Foundation

@MainActor
enum ServerFactory {
    static func create(for config: ServerConfig) -> any AgentServer {
        switch config.serverType {
        case .openCode:
            return OpenCodeServer(config: config)
        case .hermes:
            return HermesServer(config: config)
        }
    }
}
