# Agent Pocket — Architecture & Vision

> A personal AI that sees your screen, lives on your phone, and thinks on your GPU.

---

## The Idea

One AI brain (Gemma 4) running on your home PC, connected to everything:
- **Sees your screen** 24/7 via screenpipe
- **Talks to you** from your phone via AgentPocket
- **Chats with you** from your desktop via Quickshell sidebar
- **Runs for free** — no API costs, no cloud, fully private

You walk away from your desk, pull out your phone, and ask:
*"What was I working on?"* — and it knows.

---

## The Pipeline

```
Voice/Text in  →  Transcribe  →  Think  →  Respond  →  Voice/Text out
```

That's it. Everything below is just where each step runs and how they connect.

---

## System Overview

```
                        ┌─────────────────────────────────┐
                        │         HOME PC                  │
                        │         (RTX 4070 Ti 12GB)       │
                        │                                  │
                        │  ┌───────────┐  ┌────────────┐  │
                        │  │  Ollama   │  │ screenpipe  │  │
                        │  │  Gemma 4  │  │ screen      │  │
                        │  │  E2B      │  │ memory      │  │
                        │  │  :11434   │  │ :3030       │  │
                        │  └─────▲─────┘  └──────▲──────┘  │
                        │        │               │         │
                        │  ┌─────┴───────────────┴──────┐  │
                        │  │        Bridge Server        │  │
                        │  │        :8765 (WS)           │  │
                        │  │                             │  │
                        │  │  Receives text from phone   │  │
                        │  │  Grabs screen context       │  │
                        │  │  Calls Gemma 4              │  │
                        │  │  Streams response back      │  │
                        │  └──────────▲──────────────────┘  │
                        │             │                     │
                        └─────────────┼─────────────────────┘
                                      │
                                      │  WebSocket
                                      │  over Tailscale
                                      │
                     ┌────────────────┼────────────────────┐
                     │                │                     │
              ┌──────┴───────┐ ┌─────┴──────┐ ┌───────────┴──┐
              │  Quickshell  │ │ AgentPocket │ │   Future     │
              │  Sidebar     │ │ (iPhone)    │ │   (Heimdal,  │
              │              │ │             │ │    Telegram)  │
              │  Super+A     │ │  Live       │ │              │
              │  Direct to   │ │  Activity   │ │              │
              │  Ollama      │ │  on lock    │ │              │
              │              │ │  screen     │ │              │
              └──────────────┘ └─────────────┘ └──────────────┘
               At your desk     On the go        Anywhere
```

**Three interfaces. One brain. One screen memory.**

---

## How It Works In Practice

### Scenario 1: At your desk

You hit **Super+A**. Quickshell sidebar opens with Gemma 4 already
connected via Ollama. You type or talk. It responds instantly.
It already knows what's on your screen via screenpipe.

### Scenario 2: On the go

You pull out your phone. AgentPocket shows a **green dot** on your
lock screen (Live Activity). You tap it and ask:

> "What was I working on before I left?"

Phone transcribes → sends to PC → bridge grabs screen context →
Gemma 4 answers → phone speaks it back. **2 seconds.**

### Scenario 3: In bed

> "What was that error I was debugging before dinner?"

Bridge queries screenpipe for 6-8pm, finds the stack trace,
Gemma 4 summarizes: *"TypeScript type error in the bridge server —
the WebSocket message type didn't match."*

---

## What Gemma 4 Actually Sees

screenpipe captures screenshots on OS events (app switch, click,
typing pause), OCRs them, and stores the text with timestamps.

When you ask a question, the bridge builds this prompt:

```
System: You are a personal assistant. You can see what the user
has been doing on their computer via screen captures.

Recent screen activity:
---
[12:41] App: Firefox — "screenpipe docs - REST API endpoints"
[12:38] App: VS Code — "const server = Bun.serve({ websocket: {...} })"
[12:35] App: kitty — "$ curl localhost:3030/search?q=test"
---

User: what was I just doing?
```

Plain text context. No special vision needed — OCR already happened.

For visual questions ("what's that chart?"), the bridge sends the
actual screenshot as an image to Gemma 4's multimodal endpoint.

---

## Components

### What runs where

| Component           | Runs as         | Port   | Resource Use                        |
|---------------------|-----------------|--------|-------------------------------------|
| **Ollama + Gemma 4** | systemd service | 11434  | ~7GB VRAM loaded, 0 when idle       |
| **screenpipe**       | systemd service | 3030   | ~5-10% CPU, ~200MB RAM              |
| **Bridge server**    | systemd service | 8765   | ~30MB RAM, near-zero CPU when idle  |
| **Quickshell**       | already running | —      | Direct Ollama connection (built-in) |
| **AgentPocket**      | iOS app         | —      | Just a WebSocket client             |
| **Live Activity**    | iOS widget      | —      | Near-zero, managed by iOS           |

### Dependency graph

```
Ollama (:11434)         screenpipe (:3030)
       ▲                       ▲
       │ HTTP                  │ HTTP (optional)
       │                       │
       └───────┐       ┌───────┘
               │       │
          ┌────┴───────┴────┐
          │  Bridge (:8765) │
          └────────▲────────┘
                   │
                   │ WebSocket over Tailscale
                   │
          ┌────────┴────────┐
          │   AgentPocket   │
          │   (iPhone)      │
          └─────────────────┘
```

Four boxes. Three connections. Each testable alone with curl.

---

## The Protocol

The bridge speaks one simple WebSocket protocol:

```
→ Phone to PC
  { "type": "query", "text": "what was I working on?", "includeScreen": true }

← PC to Phone (streamed, one per chunk)
  { "type": "chunk", "text": "You were..." }
  { "type": "chunk", "text": " editing the bridge" }
  { "type": "done" }

← On error
  { "type": "error", "message": "Ollama not running" }
```

Three message types. That's the entire contract.

---

## Repo Structure

```
agentpocket/
│
├── AgentPocket/                    ← iOS app (existing)
│   ├── App/
│   ├── Models/
│   ├── Networking/
│   │   └── AgentBridge.swift       ← WebSocket client to PC
│   ├── State/
│   │   └── VoiceEngine.swift       ← Speech recognition + synthesis
│   └── Views/
│       └── VoiceChat/              ← Voice interaction UI
│
├── AgentPocketWidget/              ← Live Activity (new target)
│   ├── AgentActivity.swift         ← ActivityKit attributes
│   └── AgentPocketWidget.swift     ← Lock screen + Dynamic Island UI
│
├── bridge/                         ← Bridge server (Bun)
│   ├── index.ts                    ← Everything (~100 lines)
│   └── package.json
│
├── AgentPocketTests/               ← Existing tests
├── project.yml                     ← XcodeGen config
├── ARCHITECTURE.md                 ← This file
├── LICENSE
└── README.md
```

One repo. Three concerns. No shared code between Swift and TypeScript —
they communicate over WebSocket.

---

## iOS Stack

All built-in Apple frameworks. Zero third-party dependencies.

| Function        | API                        | Notes                          |
|-----------------|----------------------------|--------------------------------|
| **Voice input** | `SFSpeechRecognizer`       | On-device, free, good quality  |
| **Voice output**| `AVSpeechSynthesizer`      | Built-in, 3 lines of code     |
| **WebSocket**   | `URLSessionWebSocketTask`  | Built into Foundation          |
| **Live Activity**| `ActivityKit`             | Persistent lock screen widget  |
| **Siri shortcut**| `AppIntents`              | "Hey Siri, ask Agent Pocket…"  |

### Live Activity

Always visible on lock screen. Shows agent status (ready / thinking / speaking).
Tap to expand into full voice chat. Updates via the WebSocket connection.

Uses `BGContinuedProcessingTask` (iOS 26+) for up to 30 minutes of
background processing — keeps the audio pipeline alive without foregrounding.

---

## Desktop Stack

### Quickshell sidebar (already works)

The AI chat at **Super+A** already supports Ollama. Once Ollama is running
with Gemma 4, type `/model gemma4:e2b` in the sidebar. Done.

Config: `~/.config/illogical-impulse/config.json` → `ai.extraModels`

### screenpipe (new)

Event-driven screen + audio capture. Runs as a background service.
REST API at `:3030`. The bridge queries it — screenpipe doesn't need
to know about Gemma 4 or AgentPocket.

---

## Build Phases

| Phase | What                                          | Effort        |
|-------|-----------------------------------------------|---------------|
| **1** | Install Ollama + Gemma 4 + Quickshell sidebar | 30 minutes    |
| **2** | Write bridge server (WebSocket → Ollama)      | One afternoon  |
| **3** | AgentPocket: voice + WebSocket + display       | A few days     |
| **4** | Live Activity on lock screen                   | A day          |
| **5** | screenpipe + feed context into bridge           | A day          |
| **6** | Siri shortcut via App Intents                   | A few hours    |

Phase 1-2 = working prototype (test from terminal).
Phase 3-4 = real product on your phone.
Phase 5 = the magic (screen awareness).
Phase 6 = polish.

---

## Ideas & Future Directions

### Near-term

- **Screen-aware answers** — "What's that error?" reads your terminal.
  "What's in that chart?" sends the screenshot to Gemma 4 vision.
- **Conversation history** — SQLite in the bridge, persist across sessions.
  "What did I ask you yesterday about the Heimdal cron jobs?"
- **Quickshell notifications** — When the phone asks something, show the
  interaction on your desktop too. See what your phone-self is asking.

### Medium-term

- **Hermes agent integration** — Swap the simple bridge for Hermes
  (Nous Research). Gets you self-improving skills, persistent memory,
  and autonomous task execution. Same Ollama backend.
- **Heimdal bridge** — Connect Gemma 4 as a secondary model in Heimdal.
  Route cheap tasks (daily briefs, content drafts, cron jobs) to local
  inference. Keep Claude for complex work. Zero API cost for routine work.
- **Multi-model routing** — E2B for fast answers, swap to 26B MoE
  (when VRAM allows) for hard reasoning. Bridge decides based on
  question complexity.

### Long-term

- **Ambient reasoning** — Instead of waiting for questions, the bridge
  periodically checks screenpipe and proactively nudges you.
  "You've been on this error for 10 minutes — want me to look into it?"
- **Learn from patterns** — Track what you ask, when, and about what.
  Pre-fetch screen context for your typical workflows. Know that at 9am
  you'll ask about email, at 2pm about code.
- **AgentPocket as universal client** — Not just for your PC. Connect to
  any Ollama instance, any friend's bridge, any Huginn-hosted agent.
  One app, many brains.

---

## Honest Limitations

| Reality                              | Impact                                  | Mitigation                                     |
|--------------------------------------|------------------------------------------|-------------------------------------------------|
| Gemma 4 E2B is a 2.3B model         | Won't solve hard math or complex code    | Use Claude/bigger model for hard stuff           |
| Ollama unloads after 5min idle       | First request after idle: ~3-5s delay    | Set `OLLAMA_KEEP_ALIVE=-1`                       |
| screenpipe on Wayland                | Event capture may be partial             | Test first, fall back to periodic screenshots   |
| iOS Live Activity 8-hour limit       | Widget dies after 8 hours                | Auto-restart in background                       |
| 12GB VRAM shared with desktop        | Can't run huge models alongside desktop  | E2B fits in 7GB, leaves room for everything     |
| Tailscale required                   | Phone must be on Tailscale network       | Already set up, zero-config                      |

---

## What We're NOT Building

| Temptation                  | Why we skip it                                    |
|-----------------------------|---------------------------------------------------|
| On-device LLM on iPhone     | Phone is just mic + speaker + display              |
| Custom wake word SDK         | Tap-to-talk first. Siri shortcut later. Free.      |
| Custom TTS engine            | AVSpeechSynthesizer works. Upgrade later.          |
| Agent framework (day one)    | Ollama API is enough. Add Hermes when needed.       |
| Database (day one)           | Start stateless. Add SQLite when we need history.   |
| Docker / containers          | One Bun file. systemd is enough.                    |
| CI/CD pipeline               | One developer. Push and build locally.              |
| Shared types package         | 3 message types. Just duplicate them.               |

---

## Key Principles

1. **One file per concern** — Bridge is one file. Voice engine is one file.
2. **Test each piece alone** — curl the bridge, curl Ollama, curl screenpipe.
3. **No middleware** — Text goes in, text comes out. No queues, no brokers.
4. **Built-in APIs first** — Apple Speech, Apple TTS, Bun WebSocket. Zero deps.
5. **Add complexity only when it hurts** — Start simple, measure, then improve.

---

## Reference Projects

| Project                                                       | Stars  | What to learn from it                                |
|---------------------------------------------------------------|--------|------------------------------------------------------|
| [screenpipe](https://github.com/screenpipe/screenpipe)         | 17.9k  | Event-driven screen capture, REST API, MCP server    |
| [Volocal](https://github.com/fikrikarim/volocal)              | —      | iOS local voice pipeline, echo cancellation, barge-in |
| [Porcupine](https://github.com/Picovoice/porcupine)           | 4.8k   | iOS background wake word detection                    |
| [Speech-Swift](https://github.com/soniqo/speech-swift)        | 515    | Streaming speech-to-speech, multiple STT/TTS models  |
| [UI-TARS](https://github.com/bytedance/UI-TARS-desktop)       | 29.2k  | Vision → action planning, event-driven protocol      |
| [Hermes Agent](https://github.com/NousResearch/hermes-agent)  | 23.2k  | Self-improving agent, skill creation, memory          |

---

*Last updated: April 2026*
