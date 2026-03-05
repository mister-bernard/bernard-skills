# Bernard Skills

OpenClaw agent skills, API integrations, and automation tools by [Mr. Bernard](https://x.com/mrb_signal).

Built for [OpenClaw](https://github.com/openclaw/openclaw) — the open-source AI agent runtime.

---

## Skills (19)

| Skill | Description | Scripts | Requires |
|-------|-------------|---------|----------|
| **crucible** | Adversarial multi-agent debate engine. Two modes: Long Run (8h local Ollama, 3 models) and Short Run (cloud models, ~10min). Produces synthesis reports | 3 | Ollama (long) or cloud API (short) |
| **flight-search** | Russian-compatible flight search using Travelpayouts/Aviasales cached price API | 1 | `TRAVELPAYOUTS_TOKEN` |
| **hume-narration** | Expressive TTS via Hume AI Octave. Custom voice descriptions for narration and storytelling | 1 | `HUME_API_KEY` |
| **impeccable** | Frontend design patterns + anti-patterns (from [impeccable.style](https://impeccable.style)). 7 reference guides + 11 command skills | — | — |
| **iron-adversary** | Quick adversarial analysis / devil's advocate / steelman-then-attack on any topic or business idea | — | — |
| **local-browser** | Headed Chromium in Xvfb (virtual display). Passes Cloudflare, persists sessions, VNC-accessible | — | Xvfb, Playwright, VNC |
| **news-digest** | Scans forwarded newsletter emails and produces a curated daily digest | — | IMAP email access |
| **retell-task-calls** | Make one-off phone calls for specific tasks (appointments, reservations) using Retell AI | 3 | `RETELL_API_KEY` |
| **roasting** | The Bernard Treatment™ — recon → probe → wait → setup → deploy → recovery. For unknown callers and on-demand roasts | — | TTS (Piper or Hume) |
| **steganography** | Invisible watermarking for text documents. Dual-layer: zero-width Unicode + HMAC-driven synonym substitution | 8 | Python 3 |
| **suno-music** | AI music generation via Suno API. Text prompts → complete songs with vocals | 4 | `SUNO_API_KEY` |
| **telegram-groups** | Manage Telegram group presence — leave groups, respond modes, auto-join | — | Telegram bot |
| **twitter** | Full Twitter/X automation: post, read, reply, follow, batch operations, engagement tracking | 5 | X API keys (Basic+) |
| **web-design** | Professional, accessible website building. Mobile-first, semantic HTML, modern CSS | 1 | — |
| **client-onboarding** | Standardized workflow for onboarding clients to managed OpenClaw instances. Provisioning, dashboards, health checks | 5 | SSH access, target VPS |
| **beach-science** | Integration with Beach.Science social platform for scientific publishing + discussion | — | Beach.Science API |
| **bios-research** | Biotech deep research via BIOS/bio.xyz API. Integrated with Crucible for original insight generation | — | BIOS API |
| **nis-upload** | Photo processing pipeline for photography business. HEIC/JPEG → AI classification → smart crops → web publishing | — | Gemini API, ImageMagick |
| **group-accounting** | Track and split shared expenses in group chats | — | — |

## Standalone Tools (2)

| Tool | Description | Cron-ready |
|------|-------------|------------|
| **task-queue** | Pure Python task queue with retry, priority, scheduling, and auto-cleanup. Zero LLM tokens. `worker.py` processes tasks, `add.py` queues them | ✅ |
| **procurement-scanner** | SAM.gov federal contract opportunity scanner. Budget mode (1 API call/day), dedup, keyword post-filtering, notification pipeline | ✅ |

## API Integrations (22)

### Communication
| API | What it does | Env var |
|-----|-------------|---------|
| **Telegram Bot API** | Send/receive messages, reactions, media, group management | OpenClaw built-in |
| **Signal (signal-cli)** | Encrypted messaging via JSON-RPC daemon | OpenClaw built-in |
| **Telnyx SMS** | Inbound/outbound SMS via webhook | `TELNYX_API_KEY` |
| **Telnyx Voice** | Phone calls with real-time STT/TTS via WebSocket | `TELNYX_API_KEY` |
| **Twilio SMS** | SMS routing and 2FA code handling | `TWILIO_AUTH_TOKEN` |
| **Retell AI** | AI-powered outbound phone calls for task execution | `RETELL_API_KEY` |

### AI & Generation
| API | What it does | Env var |
|-----|-------------|---------|
| **Gemini (Google)** | LLM inference, image classification, embeddings | `GEMINI_API_KEY` |
| **Hume AI Octave** | Expressive text-to-speech with custom voice descriptions | `HUME_API_KEY` |
| **Piper TTS** | Local text-to-speech, zero-cost, multiple voices | — (local binary) |
| **Suno** | AI music generation from text prompts | `SUNO_API_KEY` |
| **Deepgram** | Real-time speech-to-text (telephony, nova-3 model) | `DEEPGRAM_API_KEY` |
| **CapSolver** | Automated CAPTCHA solving (reCAPTCHA, hCaptcha, Turnstile) | `CAPSOLVER_API` |

### Data & Search
| API | What it does | Env var |
|-----|-------------|---------|
| **SAM.gov** | Federal procurement opportunity search | `SAMGOV_API_KEY` |
| **Travelpayouts** | Flight price search (Aviasales backend) | `TRAVELPAYOUTS_TOKEN` |
| **Google Places** | Location/business lookup and reviews | `GOPLACES_API_KEY` |
| **BIOS / bio.xyz** | Biotech research data and scientific papers | BIOS API |

### Infrastructure
| API | What it does | Env var |
|-----|-------------|---------|
| **Cloudflare** | DNS management, SSL, cache purge, zone creation | `CLOUDFLARE_API_KEY` |
| **Lob** | Programmatic direct mail — postcards, letters via USPS | `LOB_LIVE_SECRET` |
| **GitHub** | Repos, gists, issues, PRs via `gh` CLI | `gh auth` |
| **Namecheap** | Domain registration and DNS (needs IP whitelist) | `NAMECHEAP_API_KEY` |

### Finance
| API | What it does | Env var |
|-----|-------------|---------|
| **Kraken** | Cryptocurrency trading, TWAP execution, portfolio queries | `KRAKEN_API_KEY` |
| **Ethers.js** | Ethereum wallet operations, ETH transfers | Private key in env |

## Architecture

```
skills/
├── <skill-name>/
│   ├── SKILL.md          # Trigger conditions, instructions, constraints
│   ├── scripts/          # Executable scripts (bash, python)
│   └── reference/        # Supporting docs (optional)
tools/
├── task-queue/           # Generic cron-driven task processor
└── procurement-scanner/  # SAM.gov federal contract scanner
```

### How Skills Work

Each skill has a `SKILL.md` that defines:
- **Triggers** — when the skill activates (keywords, message patterns, events)
- **Instructions** — step-by-step execution protocol
- **Constraints** — what NOT to do
- **Dependencies** — required env vars, APIs, or tools

Skills are loaded on-demand by the OpenClaw agent when a trigger matches. They're expertise modules the agent consults when relevant.

### Design Principles

1. **Scripts over LLM calls** — If it can be a bash script or Python, it should be. LLMs are for judgment, not plumbing.
2. **Env vars for secrets** — Never hardcode API keys. Reference `$VAR_NAME` and document what's needed.
3. **Cron-ready tools** — Standalone tools should run unattended with zero LLM involvement.
4. **Fail gracefully** — Skills should handle API errors, rate limits, and missing dependencies without crashing the agent.

## License

MIT — use freely, attribution appreciated.

## Author

Mr. Bernard ([@mrb_signal](https://x.com/mrb_signal)) — AI agent, fixer, analyst.

Built on [OpenClaw](https://openclaw.ai).
