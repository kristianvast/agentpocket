import Foundation
import Observation

enum PTYConnectionState: Sendable, Equatable {
    case idle
    case connecting
    case connected
    case disconnected
    case error(String)
}

@MainActor
@Observable
final class PTYWebSocket: NSObject {
    let url: URL
    private(set) var connectionState: PTYConnectionState = .idle
    var onData: ((Data) -> Void)?
    var onMetadata: ((PtyMetadata) -> Void)?

    private let authorization: String?
    private let session: URLSession
    private var webSocketTask: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var shouldReconnect = false
    private var reconnectDelayNanoseconds: UInt64 = 500_000_000

    init(baseURL: String, ptyID: PtyID, authorization: String? = nil) {
        self.authorization = authorization
        self.url = PTYWebSocket.makeWebSocketURL(baseURL: baseURL, ptyID: ptyID)
        let configuration = URLSessionConfiguration.default
        self.session = URLSession(configuration: configuration)
        super.init()
    }

    func connect() {
        guard connectionState == .idle || connectionState == .disconnected || isErrorState else {
            return
        }
        shouldReconnect = true
        startConnection()
    }

    func disconnect() {
        shouldReconnect = false
        reconnectTask?.cancel()
        reconnectTask = nil
        receiveTask?.cancel()
        receiveTask = nil
        pingTask?.cancel()
        pingTask = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        connectionState = .disconnected
    }

    func sendInput(_ text: String) async throws {
        guard let webSocketTask, connectionState == .connected else {
            throw OpenCodeError.networkError(URLError(.notConnectedToInternet))
        }
        do {
            try await webSocketTask.send(.string(text))
        } catch {
            throw OpenCodeError.networkError(error)
        }
    }

    private var isErrorState: Bool {
        if case .error = connectionState {
            return true
        }
        return false
    }

    private func startConnection() {
        reconnectTask?.cancel()
        connectionState = .connecting

        var request = URLRequest(url: url)
        if let authorization {
            request.setValue(authorization, forHTTPHeaderField: "Authorization")
        }

        let task = session.webSocketTask(with: request)
        webSocketTask = task
        task.resume()

        connectionState = .connected
        reconnectDelayNanoseconds = 500_000_000
        startReceiveLoop()
        startPingLoop()
    }

    private func startReceiveLoop() {
        receiveTask?.cancel()
        receiveTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                guard let webSocketTask = self.webSocketTask else { return }
                do {
                    let message = try await webSocketTask.receive()
                    await self.handle(message: message)
                } catch {
                    await self.handleConnectionError(error)
                    return
                }
            }
        }
    }

    private func startPingLoop() {
        pingTask?.cancel()
        pingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                guard !Task.isCancelled else { return }
                guard let webSocketTask = self.webSocketTask else { return }
                do {
                    try await self.sendPing(task: webSocketTask)
                } catch {
                    await self.handleConnectionError(error)
                    return
                }
            }
        }
    }

    private func sendPing(task: URLSessionWebSocketTask) async throws {
        try await withCheckedThrowingContinuation { continuation in
            task.sendPing { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func handle(message: URLSessionWebSocketTask.Message) async {
        switch message {
        case .data(let data):
            await handleBinary(data)
        case .string(let text):
            if let data = text.data(using: .utf8) {
                onData?(data)
            }
        @unknown default:
            break
        }
    }

    private func handleBinary(_ data: Data) async {
        guard let first = data.first else {
            return
        }

        if first == 0x00 {
            let metadataData = Data(data.dropFirst())
            do {
                let metadata = try JSONDecoder().decode(PtyMetadata.self, from: metadataData)
                onMetadata?(metadata)
            } catch {
                connectionState = .error(String(describing: error))
            }
        } else {
            onData?(data)
        }
    }

    private func handleConnectionError(_ error: Error) async {
        receiveTask?.cancel()
        receiveTask = nil
        pingTask?.cancel()
        pingTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil

        if shouldReconnect {
            connectionState = .disconnected
            scheduleReconnect()
        } else {
            connectionState = .error(String(describing: error))
        }
    }

    private func scheduleReconnect() {
        reconnectTask?.cancel()
        let delay = reconnectDelayNanoseconds
        reconnectDelayNanoseconds = min(reconnectDelayNanoseconds * 2, 30_000_000_000)

        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard let self else { return }
            guard self.shouldReconnect else { return }
            self.startConnection()
        }
    }

    private static func makeWebSocketURL(baseURL: String, ptyID: PtyID) -> URL {
        let stringID = String(describing: ptyID)
        let fallback = URL(string: "ws://localhost/pty/\(stringID)/connect") ?? URL(fileURLWithPath: "/")
        guard var components = URLComponents(string: baseURL) else {
            return fallback
        }

        if components.scheme == "https" {
            components.scheme = "wss"
        } else if components.scheme == "http" {
            components.scheme = "ws"
        }

        let suffix = "/pty/\(stringID)/connect"
        if components.path.isEmpty {
            components.path = suffix
        } else {
            components.path = components.path.hasSuffix("/") ? String(components.path.dropLast()) + suffix : components.path + suffix
        }

        return components.url ?? fallback
    }
}
