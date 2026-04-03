# AGENTS.md — AI Agent Guidelines

This document provides essential context for AI agents working in the AgentPocket codebase.

## Project Overview

AgentPocket is a native iOS client (SwiftUI, Swift 5.9) for interacting with AI coding agents. It connects to multiple server backends (OpenCode, OpenClaw, Hermes) via a unified protocol, supporting streaming chat, tool use, permissions, voice/image messaging, and terminal output.

```
├── AgentPocket/
│   ├── App/                # App entry point, theme, haptics
│   ├── Core/
│   │   ├── Models/         # Conversation, Message, Permission, ServerConfig, Identifiers
│   │   ├── Protocols/      # AgentServer protocol, ServerType, AgentCapabilities, errors
│   │   └── State/          # AppState, ConversationStore, ServerManager, ServerFactory
│   ├── Media/              # AudioPlayer, AudioRecorder, CameraCapture, MediaEncoder
│   ├── Networking/         # HTTPClient, SSEClient, WebSocketClient
│   ├── Servers/
│   │   ├── OpenCode/       # OpenCode server adapter (SSE-based)
│   │   ├── OpenClaw/       # OpenClaw server adapter
│   │   └── Hermes/         # Hermes server adapter
│   ├── Views/
│   │   ├── Components/     # CodeBlockView, MarkdownRenderer, StreamingTextView, etc.
│   │   ├── ContentRoot/    # Root navigation
│   │   ├── Conversations/  # Chat UI
│   │   ├── Media/          # Media capture views
│   │   ├── ServerBrowser/  # Server selection/config UI
│   │   └── Tools/          # Tool call display
│   └── Assets.xcassets/
├── AgentPocketTests/
│   ├── CoreTests/
│   ├── MediaTests/
│   ├── NetworkingTests/
│   └── ServerTests/
├── project.yml             # XcodeGen project definition (source of truth)
└── opencode.json           # MCP server config (Xcode, mitmproxy)
```

## Critical Rules

1. **Never edit `.xcodeproj` directly** — it is generated from `project.yml` and gitignored. Run `xcodegen generate` after changing `project.yml`.
2. **All server adapters must conform to `AgentServer` protocol** — see `Core/Protocols/AgentServer.swift`. This is the contract for server implementations.
3. **Never suppress type errors** — no `as! Any`, no force-unwraps unless truly safe. Use proper optionals.
4. **Strict concurrency** — `SWIFT_STRICT_CONCURRENCY: complete` is enabled. All `@MainActor` and `Sendable` requirements must be satisfied.
5. **Dark mode only** — the app forces `.preferredColorScheme(.dark)`. All UI must look correct on dark backgrounds.
6. **iPhone only** — `TARGETED_DEVICE_FAMILY: "1"`. No iPad layouts.

## Build System

### XcodeGen

The `.xcodeproj` is generated — never committed. After any structural change:

```bash
xcodegen generate
```

This reads `project.yml` and regenerates the Xcode project.

### Team Signing

```yaml
CODE_SIGN_STYLE: Automatic
DEVELOPMENT_TEAM: CVJWS3US42
```

If `DEVELOPMENT_TEAM` is missing from `project.yml` after a pull, add it back and regenerate.

### Build via Xcode MCP (Preferred)

Apple's official Xcode MCP is configured in `opencode.json` (`xcrun mcpbridge`). Enable it in **Xcode > Settings > Intelligence > Model Context Protocol**.

The Xcode MCP workspace tab for this project is `windowtab2`. Use these tools instead of manual DerivedData log parsing:

| Tool | Purpose |
|---|---|
| `XcodeListWindows` | Find workspace tab identifiers |
| `BuildProject(tabIdentifier)` | Trigger a build |
| `GetBuildLog(tabIdentifier, severity)` | Get structured build errors/warnings |
| `XcodeListNavigatorIssues(tabIdentifier)` | Get current Issue Navigator errors |
| `RunAllTests(tabIdentifier)` | Run test suite |
| `RunSomeTests(tabIdentifier, tests)` | Run specific tests |
| `XcodeRead(tabIdentifier, filePath)` | Read files via Xcode project structure |
| `XcodeWrite(tabIdentifier, filePath, content)` | Write files into Xcode project |
| `XcodeRefreshCodeIssuesInFile(tabIdentifier, filePath)` | Get compiler diagnostics for a file |
| `RenderPreview(tabIdentifier, sourceFilePath)` | Render SwiftUI previews |

**After any code change**: Use `GetBuildLog` and `XcodeListNavigatorIssues` to verify — not manual `gunzip | strings | grep`.

### Build Manually

Open `AgentPocket.xcodeproj` and build (Cmd+B). The project resolves SPM dependencies automatically:
- **SwiftTerm** — terminal emulation
- **MarkdownUI** — markdown rendering
- **Highlightr** — syntax highlighting

## Architecture

### Core Protocol

Every server backend implements `AgentServer`:

```swift
protocol AgentServer: AnyObject, Sendable {
    func connect() async throws
    func disconnect()
    func listConversations() async throws -> [Conversation]
    func createConversation() async throws -> Conversation
    func sendMessage(conversationID:content:) -> AsyncThrowingStream<ServerEvent, Error>
    func eventStream() -> AsyncThrowingStream<ServerEvent, Error>
    // ...
}
```

### Adding a New Server

1. Create `Servers/NewServer/` with `NewServerModels.swift` and `NewServerServer.swift`
2. Implement `AgentServer` protocol
3. Add case to `ServerType` enum in `Core/Protocols/AgentServer.swift`
4. Register in `ServerFactory`

### State Management

- `AppState` — root `@Observable` object, injected via `.environment()`
- `ConversationStore` — manages conversations and messages
- `ServerManager` — manages server connections and lifecycle

### Networking

- `HTTPClient` — standard request/response
- `SSEClient` — Server-Sent Events for streaming (used by OpenCode)
- `WebSocketClient` — WebSocket connections

## Network Debugging (mitmproxy-mcp)

Configured in `opencode.json`. Runs via `uvx --python 3.13 mitmproxy-mcp`.

Use the `network-debug` skill for the full workflow. Key points:

- **Always scope immediately**: `set_scope(["your-domain"])` to filter Apple telemetry noise
- **Port 8888** — don't use 8080
- **CA cert**: `~/.mitmproxy/mitmproxy-ca-cert.pem` — must be trusted in Keychain and Simulator

### Physical Device Setup

Use the **Tailscale IP** (`100.86.4.25`) as the proxy address — it's stable across networks unlike DHCP-assigned local IPs.

```bash
# Start mitmdump on all interfaces with full body logging
nohup uvx --python 3.13 --from mitmproxy mitmdump \
  --listen-host 0.0.0.0 --listen-port 8888 \
  --set confdir=$HOME/.mitmproxy \
  --set flow_detail=4 \
  --ignore-hosts '^(.+\.)?apple\.com:443$' \
  --ignore-hosts '^(.+\.)?icloud\.com:443$' \
  --ignore-hosts '^(.+\.)?mzstatic\.com:443$' \
  --ignore-hosts '^(.+\.)?cdn-apple\.com:443$' \
  --ignore-hosts '^(.+\.)?push\.apple\.com:443$' > /tmp/mitmproxy.log 2>&1 &
```

On iPhone: **Settings → Wi-Fi → (i) → HTTP Proxy → Manual**
- Server: `100.86.4.25` (Tailscale IP — both devices must have Tailscale running)
- Port: `8888`

**When done**: Turn off the proxy on your iPhone. Don't leave it on — switching networks with a stale proxy breaks all connectivity.

**Note**: `--ignore-hosts` regex matches against `host:port` (e.g. `gateway.icloud.com:443`), not just the hostname. The `:443$` suffix is required. `flow_detail=4` enables full request/response body logging — without it you only see status codes and sizes. SSE stream bodies are only logged when the connection closes.

### Simulator Setup

The simulator inherits macOS system proxy settings:

```bash
networksetup -setwebproxy "Wi-Fi" 127.0.0.1 8888
networksetup -setsecurewebproxy "Wi-Fi" 127.0.0.1 8888
```

**Always disable when done** — leaving this on routes all Mac traffic through mitmproxy:

```bash
networksetup -setwebproxystate "Wi-Fi" off
networksetup -setsecurewebproxystate "Wi-Fi" off
```

## Code Style

- Swift 5.9 with strict concurrency
- `@Observable` macro for state (not `ObservableObject`)
- `AsyncThrowingStream` for event streaming
- Structured concurrency (`async/await`, `TaskGroup`)
- Models are `Codable`, `Hashable`, `Sendable`
- Type aliases for IDs: `ConversationID`, `MessageID`, `ContentID`, `PermissionID` (all `String`)

## Deployment

- **Bundle ID**: `ai.agentpocket.app`
- **Min iOS**: 17.0
- **Version**: 2.0.0
