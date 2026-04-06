import Foundation

@MainActor
@Observable
final class WebSocketClient: NSObject, @unchecked Sendable {
    enum ConnectionState: Sendable {
        case idle
        case connecting
        case connected
        case disconnected
        case error(String)
    }

    private(set) var state: ConnectionState = .idle
    private var webSocketTask: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?

    private let url: URL
    private let authHeader: String?
    private let pingInterval: TimeInterval
    private let maxReconnectDelay: TimeInterval
    private let maxReconnectAttempts: Int
    private var reconnectAttempts = 0

    var onMessage: ((WebSocketMessage) -> Void)?
    var onConnect: (() -> Void)?
    var onDisconnect: ((Error?) -> Void)?

    init(url: URL, authorizationHeader: String? = nil, pingInterval: TimeInterval = 15, maxReconnectDelay: TimeInterval = 30, maxReconnectAttempts: Int = 10) {
        self.url = url
        self.authHeader = authorizationHeader
        self.pingInterval = pingInterval
        self.maxReconnectDelay = maxReconnectDelay
        self.maxReconnectAttempts = maxReconnectAttempts
        super.init()
    }

    func connect() {
        guard case .idle = state else { return }
        reconnectAttempts = 0
        state = .connecting
        establishConnection()
    }

    func disconnect() {
        receiveTask?.cancel()
        pingTask?.cancel()
        reconnectTask?.cancel()
        receiveTask = nil
        pingTask = nil
        reconnectTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        state = .idle
    }

    func send(_ text: String) async throws {
        guard let task = webSocketTask else { throw AgentPocketError.notConnected }
        try await task.send(.string(text))
    }

    func sendData(_ data: Data) async throws {
        guard let task = webSocketTask else { throw AgentPocketError.notConnected }
        try await task.send(.data(data))
    }

    private func establishConnection() {
        var request = URLRequest(url: url)
        if let authHeader {
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        }

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        let task = session.webSocketTask(with: request)
        webSocketTask = task
        task.resume()

        startReceiving()
        startPinging()
    }

    private func startReceiving() {
        receiveTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let task = self.webSocketTask else { break }
                do {
                    let message = try await task.receive()
                    switch message {
                    case .string(let text):
                        self.onMessage?(.text(text))
                    case .data(let data):
                        self.onMessage?(.binary(data))
                    @unknown default:
                        break
                    }
                } catch {
                    if !Task.isCancelled {
                        self.handleDisconnect(error: error)
                    }
                    break
                }
            }
        }
    }

    private func startPinging() {
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(self?.pingInterval ?? 15) * 1_000_000_000)
                guard !Task.isCancelled else { break }
                guard let self else { break }
                self.webSocketTask?.sendPing { [weak self] error in
                    if let error, !Task.isCancelled {
                        Task { @MainActor [weak self] in
                            self?.handleDisconnect(error: error)
                        }
                    }
                }
            }
        }
    }

    private func handleDisconnect(error: Error?) {
        receiveTask?.cancel()
        pingTask?.cancel()
        webSocketTask = nil
        state = .disconnected
        onDisconnect?(error)
        scheduleReconnect()
    }

    private func scheduleReconnect() {
        reconnectTask = Task { [weak self] in
            var delay: TimeInterval = 0.5
            let maxDelay = self?.maxReconnectDelay ?? 30

            while !Task.isCancelled {
                guard let self else { break }

                if self.reconnectAttempts >= self.maxReconnectAttempts {
                    self.state = .error("Max reconnection attempts exhausted")
                    self.onDisconnect?(NSError(domain: "WebSocketClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Max reconnection attempts exhausted"]))
                    break
                }

                self.reconnectAttempts += 1
                let jitteredDelay = UInt64(delay * Double.random(in: 0.5...1.5) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: jitteredDelay)
                guard !Task.isCancelled else { break }

                self.state = .connecting
                self.establishConnection()

                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if case .connected = self.state { break }

                delay = min(delay * 2, maxDelay)
            }
        }
    }
}

extension WebSocketClient: URLSessionWebSocketDelegate {
    nonisolated func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        Task { @MainActor [weak self] in
            self?.state = .connected
            self?.reconnectAttempts = 0
            self?.reconnectTask?.cancel()
            self?.reconnectTask = nil
            self?.onConnect?()
        }
    }

    nonisolated func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        Task { @MainActor [weak self] in
            self?.handleDisconnect(error: nil)
        }
    }
}

enum WebSocketMessage: Sendable {
    case text(String)
    case binary(Data)
}
