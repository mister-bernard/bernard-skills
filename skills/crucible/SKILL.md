# The Crucible — Adversarial Analysis Pipeline

Two modes: **Long Run** (8h local hardware, deep debate) and **Short Run** (cloud models, fast adversarial analysis).

## Long Run Crucible

Fully autonomous multi-agent debate on Mac Mini M4 Pro. Three local Ollama models debate for 8 hours, then results are harvested, synthesized, and **published to [<YOUR_DOMAIN>/debates/](https://<YOUR_DOMAIN>/debates/)**.

**Cost: $0 for debate + ~$0.15 for cloud synthesis + publish.**

## Short Run Crucible

Fast adversarial analysis using cloud models (Sonnet, etc.) via `sessions_spawn`. Three roles (Adversary → Researcher → Strategist) run sequentially in ~5-10 min. Results **published as GitHub Gists** (not on <YOUR_DOMAIN>).

**Cost: ~$0.30-1.00 depending on models.**

### Publishing Rules
| Mode | Output | Published To |
|------|--------|-------------|
| Long Run | Full synthesis report + audio | <YOUR_DOMAIN>/debates/ |
| Short Run | 3 role reports + summary | GitHub Gist |

## Architecture

```
TOPIC + RESEARCH
    │
    ▼
┌─────────────────────────────────────────────┐
│          Mac Mini M4 Pro (64GB RAM)          │
│              8 hours, $0 cost                │
│                                              │
│  🔴 Adversary (qwen2.5:32b or similar)      │
│  🔵 Researcher (llama3.1:70b or similar)     │
│  🟡 Strategist (qwen2.5-coder:32b or sim.)  │
│                                              │
│  Local Ollama → transcript.txt               │
│  Checkpoints every 50 rounds                 │
│  Final position papers at end                │
└─────────────────┬───────────────────────────┘
                  │  (8.5h later, cron fires)
                  ▼
┌─────────────────────────────────────────────┐
│          Harvest + Publish (Cloud)            │
│            Sonnet, ~$0.15, ~10 min           │
│                                              │
│  1. SCP results from Mac Mini                │
│  2. Synthesize 2000-3000 word report         │
│  3. POST to <YOUR_DOMAIN>/debates/ API              │
│  4. Notify G on Telegram with URL            │
└─────────────────────────────────────────────┘
```

## End-to-End Workflow (Fully Autonomous)

### Phase 1: Research (~5 min, Bernard main session)

1. Web search for context on the debate topic (3-5 searches)
2. Fetch 1-2 key articles for depth
3. Save to `projects/crucible-<id>/research-context.md`

### Phase 2: Deploy (~2 min, Bernard main session)

1. **Register as active debate** on <YOUR_DOMAIN>:
   ```bash
   curl -X POST http://127.0.0.1:3000/api/debates/active \
     -H 'Content-Type: application/json' \
     -H 'x-api-key: <MRB_API_KEY>' \
     -d '{"debates":[{
       "id":"<debate-id>",
       "title":"<title>",
       "topic":"<topic question>",
       "agents":[
         {"role":"<Role>","model":"<model>","stance":"<1-line stance>"},
         ...
       ],
       "infrastructure":"Mac Mini M4 Pro (64GB RAM) — local Ollama, $0 compute",
       "startedAt":"<ISO>",
       "durationHours":8,
       "expectedFinish":"<ISO start + 8h>",
       "status":"running"
     }]}'
   ```
   This shows the debate as "🔴 LIVE" on <YOUR_DOMAIN>/debates/ with a progress bar.

2. Generate `debate.py` with:
   - 3 personas (Bull/Bear/Strategist or Adversary/Researcher/Strategist or custom)
   - 12-15 topic prompts that structure the debate progression
   - Research context injected into system prompts
   - 8-hour duration, checkpoints every 50 rounds
2. SCP debate.py + research-context.md to Mac Mini
3. Launch: `nohup python3 debate.py > debate.log 2>&1 &`
4. Verify first responses are generating (check after ~60s)

### Phase 3: Debate (8 hours, Mac Mini, $0)

Runs entirely autonomously. No monitoring needed.

- Local Ollama models grind through hundreds of rounds
- Transcript grows to 500-1000KB
- Checkpoints saved every 50 rounds (crash recovery)
- Final position papers generated automatically at completion

### Phase 4: Harvest + Publish (~10 min, cron, ~$0.15)

A one-shot cron job fires 30 minutes after expected completion:

```bash
openclaw cron add \
  --name "crucible-<id>-harvest" \
  --at "<debate_start_UTC + 8h30m, ISO format>" \
  --delete-after-run \
  --model "anthropic/claude-opus-4-6" \
  --announce \
  --message "CRUCIBLE HARVEST: <topic>

RETRIEVE:
Run: mkdir -p projects/crucible-<id>/retrieved
Run: sshpass -p \"$MAC_MINI_PW\" scp -r administrator@$MAC_MINI_IP:~/crucible-<id>/* projects/crucible-<id>/retrieved/

CHECK COMPLETION:
If debate.py is still running (ps aux | grep debate.py), wait 30 min and re-check.
If no transcript.txt exists, report failure to G.

SYNTHESIZE (use Opus subagent — synthesis model must match or exceed debate quality):
1. Copy transcript + final positions from Mac Mini to VPS: projects/crucible-<id>/source/
2. Extract key exchanges: first ~120 lines per topic section + all final position papers
3. Save combined source to projects/crucible-<id>/source-excerpts.txt
4. Spawn Opus subagent with task (use --model anthropic/claude-opus-4-6 — synthesis MUST use a model at least as capable as the debate participants):
   - Read the source excerpts file
   - Read the Black Swan debate (data/debates/black-swan-ai-2026-02-24.json content field) as QUALITY REFERENCE
   - Write **MARKDOWN** (not HTML!) synthesis to /tmp/crucible-<id>-synthesis.md
   - Min 3000-5000 words, real quotes from transcript, specific data points
   - Sections: Executive Summary, Key Arguments by Position (with evolution phases + quotes),
     Points of Convergence, Unresolved Tensions, Novel Insights, Methodology Note, Verdict
   Unresolved Tensions, Novel Insights, Methodology Note, Verdict

PUBLISH:
POST to http://127.0.0.1:3000/api/debates/publish
- Header: x-api-key: <MRB_API_KEY from env>
- Header: Content-Type: application/json
- Body: {id, title, content (full synthesis markdown), summary (2-3 sentences),
  verdict, tags[], date}
Use a temp file + node/python to construct the POST body with the full content.

GENERATE AUDIO:
Convert synthesis to podcast audio:
1. Strip markdown from synthesis.md → /tmp/debate-podcast.txt
2. Split into ~2000 char chunks at sentence boundaries
3. Generate WAV per chunk: cat chunk.txt | piper --model /home/openclaw/.local/share/piper/voices/en_US-joe-medium.onnx --output_file chunk.wav
4. Concatenate + convert: ffmpeg -f concat -safe 0 -i filelist.txt -c:a aac -b:a 128k /tmp/<id>.m4a
5. Add audio to debate: bash scripts/add-debate-audio.sh /tmp/<id>.m4a <debate-id>
   (This copies the file, gets duration via ffprobe, updates both the debate JSON and the index with audioUrl + audioDuration)

CLEAR ACTIVE:
POST to http://127.0.0.1:3000/api/debates/active with x-api-key header.
Body: {\"debates\":[]}  — removes the LIVE indicator from the website.

NOTIFY:
Send G the URL on Telegram: https://<YOUR_DOMAIN>/debates/<id>"
```

### Phase 5: Verify (optional, manual)

Check [<YOUR_DOMAIN>/debates/](https://<YOUR_DOMAIN>/debates/) to confirm publication.

## Model Requirements

### CRITICAL: Minimum Model Sizes

| Role | Minimum Size | Recommended | Why |
|------|-------------|-------------|-----|
| Any debater | 8B+ params | qwen2.5:32b, nous-hermes2-mixtral | Sub-7B models CANNOT maintain coherent multi-turn arguments |
| Adversary | 8B+ | qwen2.5:32b | Needs to find real flaws, not repeat surface objections |
| Researcher | 8B+ | nous-hermes2-mixtral | Needs depth for evidence-based rebuttals |
| Strategist | 8B+ | qwen3:8b | Concise synthesis, fits in RAM alongside 2 larger models |

**RETIRED: llama3.1:70b** — 42.5GB, can't run alongside other models without RAM exhaustion. Caused Bear failure in trading cards debate. Use the standard trio instead.

**LESSON LEARNED (2026-02-24):** In the Black Swan debate, samantha-mistral (4.1GB) produced EMPTY responses for all 640 rounds. Haiku-class models also can't cooperate on shared transcript format. **Use 32B+ minimum for ALL roles. No exceptions.**

### Cross-Provider Diversity
Best debates use different model FAMILIES for genuine reasoning diversity:
- Qwen vs Llama vs Mistral (local)
- Or: Grok vs Sonnet vs Gemini (cloud, if budget allows)

## Mac Mini Setup

- **Host:** `$MAC_MINI_IP`, user: `administrator`, auth: `$MAC_MINI_PW` env var
- **Hardware:** M4 Pro, 64GB RAM — fits 2x 32B models comfortably, or 1x 70B + 1x 32B
- **Ollama:** `/opt/homebrew/bin/ollama` (must be in PATH for SSH commands)
- **Python:** 3.9 with `requests` installed
- **No tmux/brew** — use `nohup` for background. `screen` available at `/usr/bin/screen`

### Available Models (as of 2026-02-24)
- qwen2.5:32b (19.9GB) ✅ standard trio
- nous-hermes2-mixtral (26.4GB) ✅ standard trio
- qwen3:8b (5.2GB) ✅ standard trio (sufficient for 3rd seat)
- qwen2.5-coder:32b-instruct (19.9GB) ✅ alternate
- dolphin-mixtral (26.4GB) ✅ alternate
- llama3.1:70b (42.5GB) ⚠️ SOLO ONLY — too big for multi-model
- samantha-mistral (4.1GB) ❌ too small, proven failure

### To Pull New Models
```bash
sshpass -p "$MAC_MINI_PW" ssh administrator@$MAC_MINI_IP \
  'export PATH=$PATH:/opt/homebrew/bin && ollama pull <model>'
```

## Publishing API

**Endpoint:** `POST http://127.0.0.1:3000/api/debates/publish`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | string | no | URL slug (auto-generated if omitted) |
| title | string | yes | Debate title |
| content | string | yes | Full synthesis report in Markdown |
| summary | string | no | 2-3 sentence summary for index page |
| verdict | string | no | One-word verdict (e.g., CONVERGENT, ANTIFRAGILE, BEARISH) |
| tags | string[] | no | Topic tags |
| date | string | no | ISO date of the debate |

**Auth:** `x-api-key` header with `MRB_API_KEY`
**Returns:** `{url, id}`

**Topic suggestions API** (public, for visitors):
- `POST /api/debates/suggest` — `{topic}` (min 10 chars, rate-limited 3/IP/hour)
- `GET /api/debates/suggestions` — returns suggestions sorted by votes
- `POST /api/debates/vote` — `{id}` (one vote per IP per suggestion)

## debate.py Template

The Python debate script follows this structure:

```python
PERSONAS = {
    "Role_Name": {
        "model": "model-name",
        "system": "System prompt with research context injected..."
    }
}

TOPICS = [
    "Opening statements: ...",
    "Specific angle 1: ...",
    "Specific angle 2: ...",
    # 12-15 topics that progress from broad to specific
    "Final synthesis: ..."
]

# Main loop: rotate speakers through topics for 8 hours
# Checkpoints every 50 rounds
# Final position papers at end
```

Key design choices:
- **3 personas** (not 2, not 4) — triangle dynamic prevents stalemates
- **12-15 structured topics** — prevents circular arguments, forces new ground each hour
- **400-600 word responses** — long enough for substance, short enough for many rounds
- **Temperature 0.8** — enough creativity without incoherence
- **2-second pause between rounds** — prevents Ollama overload

## CRITICAL: Content Format

**Content MUST be Markdown, NOT HTML.** The `renderDebatePage()` function in server.js escapes all HTML first, then converts markdown to HTML. If you submit raw HTML tags, they'll be double-escaped and render as literal `<h2>` text on the page.

Use:
- `## Heading` not `<h2>Heading</h2>`
- `**bold**` not `<strong>bold</strong>`
- `*italic*` not `<em>italic</em>`
- `- list item` not `<li>list item</li>`
- `> blockquote` not `<blockquote>text</blockquote>`

**Data storage:** Individual `.json` files in `DATA_DIR/debates/` are the source of truth (e.g., `black-swan-ai-2026-02-24.json`). The combined `debates.json` exists for the index listing but individual files are what the debate page endpoint reads.

## Standard 3-Model Debate Trio

Since llama3.1:70b was retired from multi-model debates (too much RAM), the standard trio is:
- **qwen2.5:32b** (19.9GB) — analytical, data-driven
- **nous-hermes2-mixtral** (26.4GB) — creative, broad reasoning
- **qwen3:8b** (5.2GB) — concise, fast responses
- **Peak RAM: ~61.5GB (96% of 64GB)** — near max but stable

## Auto-Notification + Auto-Publish Pipeline

### Flow (fully autonomous)
```
Mac Mini debate completes
  → notify-complete.sh (cron */5) POSTs to https://<YOUR_DOMAIN>/api/crucible/complete
  → server writes ~/mrb-sh/data/crucible-completion.json
  → crucible-auto-publish.sh (cron */15) detects new completion
  → pulls summary + final positions + transcript tail from Mac Mini via SCP
  → saves to workspace/projects/crucible/results/<job_id>/
  → wakes Bernard via `openclaw chat` with synthesis instructions
  → Bernard reads positions, writes synthesis, publishes via /api/debates/publish
  → updates projects/crucible/published.json (prevents duplicate publishing)
  → deletes crucible-completion.json
  → notifies G on Telegram with published URL
```

### Key Files
- **Mac Mini:** `~/crucible/notify-complete.sh` — detects completion, POSTs to VPS
- **VPS cron:** `scripts/crucible-auto-publish.sh` — every 15 min, checks for completion file
- **Published log:** `projects/crucible/published.json` — tracks all published job_ids
- **Results cache:** `projects/crucible/results/<job_id>/` — local copies of Mac Mini outputs

### Manual Override
If the auto-pipeline fails, manually synthesize and publish:
```bash
# 1. Pull results from Mac Mini
scp -r administrator@$MAC_MINI_IP:~/crucible/results/<dir>/ /tmp/debate/
# 2. Read final positions, write synthesis JSON
# 3. Publish
curl -X POST https://<YOUR_DOMAIN>/api/debates/publish \
  -H "Content-Type: application/json" \
  -H "x-api-key: $MRB_API_KEY" \
  -d @synthesis.json
```

**This makes the long run fully autonomous: queue a topic → debate runs → notification fires → synthesis publishes → next topic queues.**

The `~/crucible/queue.json` format:
```json
[{"id": "<random-8char>", "topic": "...", "requested_by": "...", "requested_at": "ISO", "priority": true}]
```

**CRITICAL:** Queue items MUST have an `id` field or the runner crashes.

## Live Status Ping System

Mac Mini runs `~/crucible-ping.py` which pushes status to VPS every 60s:
- `POST /api/crucible/status` (authenticated, MRB_API_KEY) — receives pings from Mac Mini
- `GET /api/crucible/status` (public) — returns current status for website
- When a suggestion is queued/running, it's auto-removed from suggestions list
- Progress bar on <YOUR_DOMAIN>/debates/ uses `elapsed_hours`/`remaining_hours` from pinger (not browser Date math)

## Completed Debates

| Date | Topic | ID | Models | Rounds | URL |
|------|-------|----|----|--------|-----|
| 2026-02-24 | Black Swan Events & AI Superintelligence | black-swan-ai-2026-02-24 | nous-hermes2-mixtral, dolphin-mixtral, samantha-mistral | 640 | [Link](https://<YOUR_DOMAIN>/debates/black-swan-ai-2026-02-24) |
| 2026-02-24 | Trading Cards ↔ NFTs: Convergence or Collision? | trading-cards-nft-2026-02-24 | qwen2.5:32b, llama3.1:70b, qwen2.5-coder:32b-instruct | 65 | [Link](https://<YOUR_DOMAIN>/debates/trading-cards-nft-2026-02-24) |

## Short Run Crucible (Detail)

Fast adversarial analysis using cloud models via `sessions_spawn`. **Default format: 3v3 + Mediator.**

### Format: 3 Bulls vs 3 Bears + 1 Mediator

Each side gets 3 agents with DIFFERENT perspectives:

**BULL (FOR) agents — spawn ALL in parallel:**
| Agent | Perspective | Prompt Focus |
|-------|------------|-------------|
| Bull 1 | General/Strategic | Core reasons to do it, comparable deals, timing |
| Bull 2 | Financial/Quantitative | NPV, opportunity cost, risk-adjusted returns, market data |
| Bull 3 | Market Timing/Trends | Cycle analysis, competitive landscape, window of opportunity |

**BEAR (AGAINST) agents — spawn ALL in parallel:**
| Agent | Perspective | Prompt Focus |
|-------|------------|-------------|
| Bear 1 | General/Strategic | Why the asset is undervalued, category-defining potential |
| Bear 2 | Technology/Future | Technological trends that increase future value |
| Bear 3 | Negotiation/Deal Structure | Counter-offers, structured deals, leverage analysis |

**All 6 run in parallel** (Sonnet, `runTimeoutSeconds: 300`). Each writes 800-1200 words to `/tmp/<topic>-bull-{1,2,3}.md` and `/tmp/<topic>-bear-{1,2,3}.md`.

**MEDIATOR — spawns AFTER all 6 complete:**
- Reads all 6 position papers
- Writes structured synthesis: strongest arguments per side, vulnerabilities, areas of agreement, **FINAL VERDICT with confidence level**
- Saves to `/tmp/<topic>-mediator.md`

### Automation Flow

1. Receive topic from user
2. Spawn 6 agents in parallel (3 bull, 3 bear) — each gets a specific perspective and writes to `/tmp/`
3. Wait for all 6 to complete (auto-announced)
4. Spawn mediator agent — reads all 6, writes synthesis
5. When mediator completes, publish as GitHub Gist (all 7 files)
6. Send G the Gist URL

**The entire pipeline auto-continues.** When subagent completions arrive, check how many of the 6 position agents are done. When all 6 are in, auto-spawn the mediator. When mediator finishes, auto-publish.

### Key Rules
- **Sonnet minimum for all agents** — free models timeout/produce garbage
- **Each agent gets a UNIQUE perspective** — don't just say "argue for/against"
- **800-1200 words per position** — enough for substance, short enough to synthesize
- **Mediator must pick a side** — no cop-out "both sides have merit" conclusions
- **All files go to /tmp/** — ephemeral, not worth persisting

### Legacy Format: Sequential 3-Agent

Still available for simpler analyses:
1. **Adversary** (Sonnet) — tears the proposal apart
2. **Researcher** (Sonnet) — neutral fact-check (reads Adversary output)
3. **Strategist** (Sonnet) — synthesizes into recommendation (reads both)

Use when the question is simpler or doesn't have clear for/against sides.

**Lesson (2026-02-24):** Do NOT use `openrouter/free` for any role — they timeout at 2min. Use Sonnet minimum.

## Research Basis

1. **Heterogeneous models** — different model families produce better adversarial debate than homogeneous
2. **Shared transcript (blackboard architecture)** — simple, debuggable, auditable
3. **Dialectical structure** — thesis → antithesis → synthesis
4. **Steelman requirement** — forces genuine engagement, prevents strawmanning
5. **Adaptive escalation** — surface challenges early, structural critiques later
6. **Concession protocol** — agents must concede when beaten
7. **Evidence tiers** — quality over quantity

## Adding Audio to a Debate

Standard procedure for attaching audio to any published debate:

```bash
bash scripts/add-debate-audio.sh <audio-file> <debate-id>
# Example: bash scripts/add-debate-audio.sh ~/debate_podcasts/My_Debate.m4a tallinn-self-talk-2026-02-26
```

The script handles everything:
1. Copies audio to `mrb-sh/public/debates/audio/<debate-id>.<ext>`
2. Gets duration via `ffprobe` → formatted as `M:SS`
3. Updates the individual debate JSON with `audioUrl` + `audioDuration`
4. Updates the debates index (`debates.json`) with `audioUrl` + `audioDuration`
5. Verifies HTTP access

**CRITICAL field names:** The renderer uses `audioUrl` (not `audio`) and `audioDuration` (e.g. `"4:48"`). Wrong field names = silent failure.

## Files

```
skills/crucible/
├── SKILL.md              ← This file
├── README.md             ← Quick start
└── scripts/
    ├── adversary-prompt.md
    ├── researcher-prompt.md
    └── strategist-prompt.md

scripts/
└── add-debate-audio.sh   ← Standard audio attachment procedure
```
