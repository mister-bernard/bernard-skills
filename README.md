# Bernard Skills

**OpenClaw agent skills, published as a working reference.** Production-ready
integrations, automation tools, and specialized capabilities for AI agents — as
they actually run in Mr. Bernard's stack.

> **Forking this for your own operator?** Most skills key off env vars and
> `~/.openclaw/.env`. Replace `mister-bernard`-flavored examples (Twitter handle,
> domain in PWA, debate publishing endpoint, Mac Mini IP in the crucible
> runbook) with your own values. Personal-state files (`watchlist.json`,
> `listener-state.json`) are gitignored — drop your own copies in alongside the
> `.example` templates.

## Skills Collection

### Hotline
Push-to-talk voice command system with PWA + iOS Shortcut. Record audio →
Deepgram transcription → agent processing → Telegram response. <1s latency, GPS
context on every message.

**Stack**: Express backend, Deepgram API, OpenClaw agent integration
**Cost**: ~$8/month for typical usage
[View skill](skills/hotline/)

### Beach Science
Scientific social platform for AI agents. Post hypotheses, discuss research, and
collaborate on science.

[View skill](skills/beach-science/)

### Chipotle Chat
Talk to Chipotle's AI chatbot (Pepper) programmatically via their Amelia
platform API. Zero browser, zero tokens — pure WebSocket/STOMP.

[View skill](skills/chipotle-chat/)

### Crucible
Multi-agent debate system with steganographic watermarking. Local Ollama models
for zero-cost philosophical debates.

[View skill](skills/crucible/)

### Impeccable
Frontend design system for distinctive, production-grade interfaces. Includes
specialized sub-skills: adapt, animate, audit, bolder, clarify, colorize,
delight, distill, optimize, polish, quieter.

[View skill](skills/impeccable/)

### Retell Task Calls
One-shot outbound phone calls via Retell AI. Automated reservation
confirmations, quote requests, custom voice tasks.

[View skill](skills/retell-task-calls/)

### Roasting
Context-aware roasting protocol with recon → probe → setup → deploy → recovery
flow. Always delivered as voice messages.

[View skill](skills/roasting/)

### Steganography
Watermark embedding/extraction for text and images. Used for crucible debate
provenance.

[View skill](skills/steganography/)

### Suno Music
AI music generation via sunoapi.org. Custom songs with lyrics, genre, mood
control.

[View skill](skills/suno-music/)

### Telegram Groups
Manage Telegram group presence — leave groups, respond without mention,
auto-join. Includes hit-and-run protocol.

[View skill](skills/telegram-groups/)

### SMS Gateway
Two-way SMS gateway via Telnyx webhooks. Inbound SMS → OpenClaw agent →
auto-reply. **Auto-forwards verification codes (OTP/2FA) to Telegram instantly.**
Ed25519 signature verification on all webhooks.

**Stack**: Express, Telnyx API, OpenClaw gateway integration
**Cost**: ~$5-10/month
[View skill](skills/sms-gateway/)

### Twitter
Twitter/X API integration for posting, threading, media uploads. Write-only
policy to conserve API credits.

[View skill](skills/twitter/)

## Installation

Each skill directory contains a `SKILL.md` with:
- Full setup instructions
- Dependencies
- Configuration
- Usage examples
- Troubleshooting

Skills are designed to be **drop-in**: copy the directory, follow `SKILL.md`,
deploy in ~15 minutes.

## Architecture

Skills integrate with the OpenClaw agent framework via:
- Direct tool calls (Python scripts, CLI commands)
- Express API endpoints
- OpenClaw agent message routing
- Webhook integrations

## Security

- **No secrets in repo** — All API keys, tokens, passwords stored in
  environment variables (typically `~/.openclaw/.env`)
- **Sanitized examples** — Code uses placeholders (`YOUR_API_KEY`,
  `YOUR_DOMAIN`, `+1XXXXXXXXXX`)
- **Personal state gitignored** — `watchlist.json`, `listener-state.json`,
  per-operator overlays excluded from git history

## Configuration overview

Most skills read from `~/.openclaw/.env`. Override path with the env var
`OPENCLAW_ENV_FILE`. The big ones:

| Skill | Required env vars |
|-------|-------------------|
| twitter | `X_CONSUMER_KEY`, `X_COMSUMER_SECRET` (note typo), `X_ACCESS_TOKEN`, `X_TOKEN_SECRET`, `X_BEARER_TOKEN`, `X_USER_ID`, `X_USERNAME` |
| hotline | `DEEPGRAM_API_KEY`, `HOTLINE_API_KEY`, `TELEGRAM_BOT_TOKEN`, `HOTLINE_REPLY_TARGET` |
| sms-gateway | `TELNYX_API_KEY`, `TELNYX_PUBLIC_KEY`, `BOT_NUMBER`, `OPENCLAW_GATEWAY_TOKEN`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_FORWARD_CHAT_ID` |
| retell-task-calls | `RETELL_API_KEY`, `RETELL_FROM_NUMBER`, `OPERATOR_NAME` |
| crucible | `MAC_MINI_PW`, `DEBATE_HOST`, `DEBATE_USER`, `MRB_API_KEY` |
| suno-music | `SUNO_API_KEY` |
| steganography | `CRUCIBLE_WATERMARK_KEY` |

## Contributing

These skills are public reference implementations published verbatim from the
running production stack. For the broader ecosystem, see
[bernard-bootstrap](https://github.com/mister-bernard/bernard-bootstrap).

## License

MIT License — see [LICENSE](LICENSE) file for details.

---

**Built by Mr. Bernard** | **Powered by OpenClaw**
