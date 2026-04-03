# AgentPocket

A native iOS client for AI agent servers. Connect to OpenCode, OpenClaw, Hermes, or any compatible server and interact with your agents through text, voice, and images.

## Features

- **Multi-Server Support** — Connect to OpenCode, OpenClaw, and Hermes agents from a single app
- **Voice Messaging** — Record and send voice messages to multimodal AI models (Gemma 4, etc.)
- **Image Input** — Capture or select images and send them as context to your agent
- **AI Chat** — Streaming responses with markdown rendering and syntax-highlighted code blocks
- **Tool Execution** — Watch tools run in real-time with expandable input/output cards
- **Permission Approval** — Approve or deny tool execution requests from your agent
- **Real-time Updates** — SSE and WebSocket connections keep everything in sync
- **Face ID Lock** — Optional biometric authentication
- **Dark Theme** — Designed for developers, dark by default

## Supported Servers

| Server | Protocol | Status |
|--------|----------|--------|
| [OpenCode](https://github.com/sst/opencode) | REST + SSE | Full support |
| [OpenClaw](https://github.com/openclaw/openclaw) | WebSocket + HTTP | Full support |
| [Hermes](https://github.com/nousresearch/hermes-agent) | OpenAI-compatible | Full support |

## Requirements

- iOS 17.0+
- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- A running agent server

## Getting Started

```bash
git clone https://github.com/kristianvast/agentpocket.git
cd agentpocket
brew install xcodegen
xcodegen generate
open AgentPocket.xcodeproj
```

Press **Cmd+R** to build and run. On first launch, tap **Add Server** and enter your server URL.

## Architecture

```
AgentPocket/
├── App/                    Entry point and design system
├── Core/
│   ├── Protocols/          AgentServer protocol (all servers conform to this)
│   ├── Models/             Universal types: Conversation, Message, MessageContent
│   └── State/              AppState, ConversationStore, ServerManager
├── Networking/             HTTPClient, SSEClient, WebSocketClient
├── Servers/
│   ├── OpenCode/           REST + SSE adapter
│   ├── OpenClaw/           WebSocket + HTTP adapter
│   └── Hermes/             OpenAI-compatible adapter
├── Media/                  Audio recording, playback, camera, encoding
└── Views/
    ├── ContentRoot/        Root navigation and auth
    ├── ServerBrowser/      Server list and add-server form
    ├── Conversations/      Chat UI, message bubbles, prompt bar
    ├── Media/              Voice record button, audio playback, image picker
    ├── Tools/              Tool call cards, permission sheets
    └── Components/         Markdown, code blocks, streaming text
```

### Tech Stack

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI (iOS 17+) |
| State | `@Observable` (Observation framework) |
| Networking | URLSession (async/await) |
| Real-time | SSE (custom parser) + WebSocket |
| Markdown | [swift-markdown-ui](https://github.com/gonzalezreal/swift-markdown-ui) |
| Syntax Highlighting | [Highlightr](https://github.com/raspu/Highlightr) |

### Server Abstraction

All servers conform to the `AgentServer` protocol:

```swift
protocol AgentServer {
    func connect() async throws
    func listConversations() async throws -> [Conversation]
    func sendMessage(conversationID:content:) -> AsyncThrowingStream<ServerEvent, Error>
    func eventStream() -> AsyncThrowingStream<ServerEvent, Error>
}
```

Each server adapter translates its native API into universal `Conversation`, `Message`, and `MessageContent` types.

## License

MIT
