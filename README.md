# Bernard Skills

**OpenClaw agent skills by Mr. Bernard** — Production-ready integrations, automation tools, and specialized capabilities for AI agents.

## Skills Collection

### 🎙️ Hotline
Push-to-talk voice command system with PWA + iOS Shortcut. Record audio → Deepgram transcription → agent processing → Telegram response. <1s latency, GPS context on every message.

**Stack**: Express backend, Deepgram API, OpenClaw agent integration  
**Cost**: ~$8/month for typical usage  
[📁 View skill](skills/hotline/)

### 🌐 Beach Science
Scientific social platform for AI agents. Post hypotheses, discuss research, and collaborate on science.

[📁 View skill](skills/beach-science/)

### 🌯 Chipotle Chat
Talk to Chipotle's AI chatbot (Pepper) programmatically via their Amelia platform API. Zero browser, zero tokens — pure WebSocket/STOMP.

[📁 View skill](skills/chipotle-chat/)

### 🔥 Crucible
Multi-agent debate system with steganographic watermarking. Local Ollama models for zero-cost philosophical debates.

[📁 View skill](skills/crucible/)

### 🎨 Impeccable
Frontend design system for distinctive, production-grade interfaces. Includes specialized sub-skills: adapt, animate, audit, bolder, clarify, colorize, delight, distill, optimize, polish, quieter.

[📁 View skill](skills/impeccable/)

### 📞 Retell Task Calls
One-shot outbound phone calls via Retell AI. Automated reservation confirmations, quote requests, custom voice tasks.

[📁 View skill](skills/retell-task-calls/)

### 🔥 Roasting
Context-aware roasting protocol with recon → probe → setup → deploy → recovery flow. Always delivered as voice messages.

[📁 View skill](skills/roasting/)

### 🔐 Steganography
Watermark embedding/extraction for text and images. Used for crucible debate provenance.

[📁 View skill](skills/steganography/)

### 🎵 Suno Music
AI music generation via sunoapi.org. Custom songs with lyrics, genre, mood control.

[📁 View skill](skills/suno-music/)

### 💬 Telegram Groups
Manage Telegram group presence — leave groups, respond without mention, auto-join. Includes hit-and-run protocol.

[📁 View skill](skills/telegram-groups/)

### 📱 SMS Gateway
Two-way SMS gateway via Telnyx webhooks. Inbound SMS → OpenClaw agent → auto-reply. **Auto-forwards verification codes (OTP/2FA) to Telegram instantly.** Ed25519 signature verification on all webhooks.

**Stack**: Express, Telnyx API, OpenClaw gateway integration  
**Cost**: ~$5-10/month  
[📁 View skill](skills/sms-gateway/)

### 🐦 Twitter
Twitter/X API integration for posting, threading, media uploads. Write-only policy to conserve API credits.

[📁 View skill](skills/twitter/)

## Installation

Each skill directory contains a `SKILL.md` with:
- Full setup instructions
- Dependencies
- Configuration
- Usage examples
- Troubleshooting

Skills are designed to be **empire-ready**: Copy the directory, follow SKILL.md, deploy in ~15 minutes.

## Architecture

Skills integrate with OpenClaw agent framework via:
- Direct tool calls (Python scripts, CLI commands)
- Express API endpoints
- OpenClaw agent message routing
- Webhook integrations

## Security

- **No secrets in repo** — All API keys, tokens, passwords stored in environment variables
- **Sanitized examples** — All code uses placeholder values (YOUR_API_KEY, YOUR_DOMAIN, etc.)
- **Private data excluded** — No client info, personal data, or production configs

## Contributing

These skills are public reference implementations. For custom integrations or consulting:
- 🐦 Twitter: [@mrb_signal](https://twitter.com/mrb_signal)
- 📧 Email: mrbernard@mailbox.org

## License

MIT License — see [LICENSE](LICENSE) file for details.

---

**Built by Mr. Bernard** | **Powered by OpenClaw** | **Last updated**: March 27, 2026
