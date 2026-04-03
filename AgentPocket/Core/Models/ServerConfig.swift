import Foundation

// MARK: - Server Configuration

struct ServerConfig: Codable, Identifiable, Hashable, Sendable {
    let id: ServerID
    var name: String
    var url: String
    var serverType: ServerType
    var auth: ServerAuth
    var lastConnected: Date?
    var isDefault: Bool

    init(
        id: ServerID = UUID(),
        name: String,
        url: String,
        serverType: ServerType,
        auth: ServerAuth = .none,
        lastConnected: Date? = nil,
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.serverType = serverType
        self.auth = auth
        self.lastConnected = lastConnected
        self.isDefault = isDefault
    }

    var authorizationHeader: String? {
        switch auth {
        case .none:
            return nil
        case .bearerToken(let token):
            return "Bearer \(token)"
        case .basic(let username, let password):
            let credentials = "\(username):\(password)"
            guard let data = credentials.data(using: .utf8) else { return nil }
            return "Basic \(data.base64EncodedString())"
        case .deviceToken(let token):
            return "Bearer \(token)"
        }
    }
}

// MARK: - Auth

enum ServerAuth: Codable, Hashable, Sendable {
    case none
    case bearerToken(String)
    case basic(username: String, password: String)
    case deviceToken(String)

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case type, token, username, password
    }

    enum AuthType: String, Codable {
        case none, bearer, basic, device
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(AuthType.self, forKey: .type)
        switch type {
        case .none:
            self = .none
        case .bearer:
            let token = try container.decode(String.self, forKey: .token)
            self = .bearerToken(token)
        case .basic:
            let username = try container.decode(String.self, forKey: .username)
            let password = try container.decode(String.self, forKey: .password)
            self = .basic(username: username, password: password)
        case .device:
            let token = try container.decode(String.self, forKey: .token)
            self = .deviceToken(token)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .none:
            try container.encode(AuthType.none, forKey: .type)
        case .bearerToken(let token):
            try container.encode(AuthType.bearer, forKey: .type)
            try container.encode(token, forKey: .token)
        case .basic(let username, let password):
            try container.encode(AuthType.basic, forKey: .type)
            try container.encode(username, forKey: .username)
            try container.encode(password, forKey: .password)
        case .deviceToken(let token):
            try container.encode(AuthType.device, forKey: .type)
            try container.encode(token, forKey: .token)
        }
    }
}
