---
name: chipotle-chat
description: Talk to Chipotle's AI chatbot (Pepper) programmatically via their Amelia platform API. Zero browser, zero tokens — pure WebSocket/STOMP. Use when someone wants to chat with Chipotle's bot, test corporate chatbot boundaries, or just mess with a burrito bot for laughs. Triggers on "chipotle", "talk to chipotle", "pepper bot", "burrito bot".
---

# Chipotle Chat

Chat with Chipotle's customer service bot (Pepper) via reverse-engineered API. No browser needed.

## Architecture

- **Platform:** Amelia AI (SoundHound/IPsoft) at `amelia.chipotle.com`
- **Protocol:** STOMP 1.2 over SockJS WebSocket
- **Auth:** Anonymous sessions (no login required)
- **Cost:** $0 — no API keys, no tokens, no browser

## Quick Start

```bash
# Default: sends 3 test messages
node scripts/chipotle-chat.js

# Custom messages
node scripts/chipotle-chat.js "What are your hours?" "Do you have queso?"

# Accept privacy policy first (required for real conversation)
node scripts/chipotle-chat.js --accept "What's in your guacamole?"
```

## How It Works

1. `GET /Amelia/api/init` — anonymous session + CSRF token
2. `POST /Amelia/api/conversations/new` — start conversation
3. WebSocket to `/Amelia/api/sock/{server}/{session}/websocket`
4. STOMP CONNECT → SUBSCRIBE `/queue/session.{id}` → SEND to `/amelia/session.in`

## Key Details

- Pepper asks to accept privacy policy first (respond "1" to accept)
- Bot is a **decision-tree flowchart**, NOT an LLM — expects structured choices
- Sends `messageType: InboundUserUtteranceMessage` for user text
- Subscribes to `/queue/session.{sessionId}` (not `/user/queue/`)
- STOMP headers require: `X-Amelia-Session-Id`, `X-Amelia-Conversation-Id`, `X-Amelia-Message-Type`, `X-Amelia-Timestamp`
- Bot will disconnect if confused — "Thanks for messaging Chipotle, goodbye"
- SockJS WebSocket URL needs random server/session IDs in path

## Limitations

- Pepper is NOT a conversational AI — it follows scripted flows
- Off-topic messages get you disconnected
- No food ordering capability (just support)
- Rate limiting unknown — be respectful
