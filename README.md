# AgentPocket

A fully native iOS client for [OpenCode](https://github.com/sst/opencode) — the open-source AI coding assistant. Built entirely in SwiftUI, AgentPocket replaces the web UI with a first-class mobile experience.

## What is this?

OpenCode gives you an AI coding assistant that runs on your machine. AgentPocket puts that assistant in your pocket. Connect to any running OpenCode server (local, remote, or via Cloudflare Tunnel) and get the full experience natively on iPhone.

## Features

- **AI Chat** — Full conversation interface with streaming responses, markdown rendering, and syntax-highlighted code blocks
- **Tool Execution** — Watch tools run in real-time with expandable input/output cards and permission approval flow
- **File Browser** — Browse your project tree with syntax highlighting, line numbers, and unified diff view
- **Terminal** — Built-in terminal emulator (SwiftTerm) connected via WebSocket to server PTY sessions
- **Session Management** — Create, fork, revert, archive, and search sessions with swipe actions
- **Model Selection** — Browse and switch between all models configured on your OpenCode server
- **MCP Servers** — Manage Model Context Protocol server connections
- **Command Palette** — Quick access to commands, agents, and skills
- **Real-time Updates** — Server-Sent Events keep everything in sync
- **Face ID Lock** — Optional biometric authentication
- **Dark Theme** — Designed for developers, dark by default

## Screenshots

*Coming soon — build the project and see for yourself.*

## Requirements

- iOS 17.0+
- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (for generating the Xcode project)
- A running [OpenCode](https://github.com/sst/opencode) server

## Getting Started

### 1. Clone the repo

```bash
git clone https://github.com/kristianvast/agentpocket.git
cd agentpocket
```

### 2. Generate the Xcode project

```bash
brew install xcodegen  # if not installed
xcodegen generate
```

### 3. Open and run

```bash
open AgentPocket.xcodeproj
```

Press **Cmd+R** to build and run on a simulator or device.

### 4. Connect to your OpenCode server

On first launch, tap **Add Server** and enter your OpenCode server URL (e.g., `https://your-tunnel.trycloudflare.com` or `http://localhost:3000`).

## Architecture

```
AgentPocket/
├── App/           App entry point and design system
├── Models/        Codable types matching the OpenCode API
├── Networking/    HTTP client, SSE stream, WebSocket, API services
├── State/         Observable state management (AppState, SessionStore, EventReducer)
└── Views/
    ├── Components/   Reusable UI (markdown, code blocks, status indicators)
    ├── Home/         Server list and connection
    ├── Session/      Chat interface, message bubbles, tool cards
    ├── Files/        File tree, viewer, diff display
    ├── Terminal/     SwiftTerm integration with PTY WebSocket
    ├── Sidebar/      Session list and navigation
    ├── Settings/     Providers, models, general preferences
    └── Dialogs/      Model picker, permissions, questions, commands
```

### Tech Stack

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI (iOS 17+) |
| State | `@Observable` (Observation framework) |
| Networking | URLSession (async/await) |
| Real-time | Server-Sent Events (custom parser) |
| Terminal | [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) via WebSocket |
| Markdown | [swift-markdown-ui](https://github.com/gonzalezreal/swift-markdown-ui) |
| Syntax Highlighting | [Highlightr](https://github.com/raspu/Highlightr) |

### Communication Protocols

| Protocol | Purpose |
|----------|---------|
| HTTP REST | All CRUD operations (sessions, files, config, etc.) |
| SSE | Real-time event stream (message updates, tool status, permissions) |
| WebSocket | Terminal I/O (bidirectional PTY data) |

## OpenCode API Coverage

AgentPocket implements clients for the complete OpenCode API surface:

- **Sessions** — list, create, update, delete, fork, revert, abort, share, diff, summarize
- **Messages** — send (streaming), list, delete with full part-type support
- **Files** — list, read, status, text search, file search, symbol search
- **Terminal** — list PTYs, create, resize, remove, WebSocket connect
- **Providers** — list, OAuth authorization flow
- **Config** — get, update
- **Permissions** — list pending, reply (allow once/always/deny)
- **Questions** — list pending, reply, reject
- **MCP** — status, add, connect, disconnect
- **Events** — full SSE event stream with 25+ event types

## Contributing

Contributions welcome. This is a community project — open an issue or PR.

## License

MIT
