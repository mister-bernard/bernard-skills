# News Digest Skill

Scan G's forwarded newsletters in the `News` mailbox and produce a curated daily digest.

## Email Access
```bash
# List recent emails
himalaya envelope list -f News -s 20

# Read a specific email
himalaya message read -f News <ID>
```

- Account: `personal` (NOT `mailbox.org`)
- Folder flag: `-f` (NOT `--mailbox`)
- Page size: `-s` (NOT `--page-size`)

## Digest Workflow

1. **List** the last 15-20 emails in the News folder
2. **Read** each one (skip obvious spam/fundraising based on subject line)
3. **Categorize** by domain: AI/Tech, Crypto/Markets, Aviation, Energy/Climate, Biotech, Other
4. **Summarize** each in 2-3 sentences — extract the actual insight, not just the headline
5. **Rank** by relevance to G's interests (AI, crypto, aviation, biotech, DeSci)
6. **Flag** anything time-sensitive or actionable
7. **Skip list** at the bottom for low-value items (with one-line reason)

## Output Format

```
🔥 Must-Read
[Top 1-3 items with full summaries]

📊 Category Header
[Items grouped by domain]

📰 Skip
• [Item] (reason)
```

## Rules

- **NEVER dump raw email HTML/markdown** — always summarize in clean prose
- HTML newsletters render as broken markdown with image placeholders — extract text content only
- If an email is pure HTML garbage with no readable text, note it as "garbled HTML" in Skip
- Include source links where available (resolve tracking URLs with `curl -sI -L <url> | grep Location`)
- Keep the whole digest under ~500 words
- Prioritize: AI investment landscape > crypto markets > aviation safety > energy/climate > motivational content

## Cron Integration

This runs as part of the heartbeat rotation (2-4x/day) or can be triggered manually.
Track last check time in `memory/heartbeat-state.json` under `lastChecks.email`.

## Known Issues

- himalaya outputs HTML newsletters as broken markdown with `![](/img/...)` image tags — ignore these
- Tracking URLs (e.g., `eot.delphidigital.io`, `url6380.news.pitchbook.com`) need resolution via curl redirect
- Some emails are pure template/placeholder content (e.g., SpaceBase) — skip these
