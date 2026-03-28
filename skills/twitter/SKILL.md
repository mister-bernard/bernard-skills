# Twitter/X Skill — @mrb_signal

Post, read, reply, follow, and engage on Twitter as Mr. Bernard.

## Account
- Handle: `@mrb_signal`
- User ID: `2027171957880549376`
- Tier: Basic ($200/mo) — writes are cheap, reads burn credits fast
- First post: 2026-02-27

## Env Vars (in `~/.openclaw/.env`)
- `X_CONSUMER_KEY` — API Key (app)
- `X_COMSUMER_SECRET` — API Secret ⚠️ **Typo is permanent — it's COMSUMER in .env**
- `X_ACCESS_TOKEN` — User access token (Read+Write)
- `X_TOKEN_SECRET` — User access token secret
- `X_BEARER_TOKEN` — App bearer token (read-only endpoints)

## CLI Tools

### Post a tweet
```bash
bash skills/twitter/tweet.sh "Your tweet text"
```
Returns the tweet URL on success.

### Reply to a tweet
```bash
bash skills/twitter/reply.sh <tweet_id> "Reply text"
```

### Read recent tweets
```bash
bash skills/twitter/read.sh [count]
```

### Follow a user
```bash
bash skills/twitter/follow.sh <username>
```

### Follow all watchlist accounts
```bash
bash skills/twitter/batch-follow.sh [--dry-run]
```

## Listener (Automated Engagement) — ⚠️ DISABLED 2026-03-15

**Script:** `skills/twitter/listener.py` (script preserved, cron removed)
**Status:** DISABLED to save API credits. Do NOT re-enable without G's approval.
**Log:** `/tmp/twitter-listener.log`
**State:** `skills/twitter/listener-state.json`

### Why disabled
- Basic tier credits are overwhelmingly consumed by READ operations, not writes
- 30 watchlist accounts × polling every 30 min = ~1,440 API reads/day — this burned through the spend cap
- Posting (writes) is cheap; reading timelines is expensive
- Spend cap was hit on 2026-03-15 and reset by G

### How engagement should work now
- **Writing/posting:** Continue using the API (`tweet.sh`, `reply.sh`) — writes are cheap
- **Reading/engagement:** Use RSS feeds, manual browsing, or Nitter — NOT API polling
- Do NOT re-enable automated timeline polling unless tier is upgraded or G explicitly approves

### How the listener worked (for reference):
1. Polls watchlist accounts for new tweets (up to 10 accounts/run, rotates by priority)
2. Scores each tweet for reply-worthiness (priority, category, engagement, content signals)
3. Picks top 5 opportunities per cycle
4. Sends them to Bernard (via `openclaw chat`) to craft replies
5. Bernard replies using `reply.sh`, skips anything without a genuinely good take

### Watchlist
**File:** `skills/twitter/watchlist.json`

Categories: ai, crypto, defi, aviation, general
Priorities: high (always consider), medium (strong take only), low (exceptional only)

Currently tracking 30 accounts across all categories.

To add an account:
```bash
# Edit watchlist.json, then follow them:
bash skills/twitter/follow.sh <username>
```

## Content Strategy

Full plan: `projects/twitter-strategy/content-plan.md`

### Pillars (4)
| Pillar | Share | Topics |
|--------|-------|--------|
| AI/Agents | 40% | Operational war stories, contrarian takes, real practitioner signal |
| Markets/DeFi | 25% | Protocol analysis, risk frameworks, macro without degen energy |
| Aviation/Hardware | 20% | Edge computing, radio, physical infra meets AI |
| Bernard (persona) | 15% | One-liners, grandfather quotes, late-night musings |

### Voice Rules
- Short: 1-2 sentences for most tweets
- Substantive: every reply must add value
- Never sycophantic: no "great take!", no "this 🔥"
- Contrarian > agreeable: say what others won't
- Silent > mediocre: skip if you don't have a real take

### Posting cadence — 5 slots/day
| Slot | Pacific | UTC | Focus |
|------|---------|-----|-------|
| Morning insight | 08:00 | 15:00 | Lessons learned |
| Midday take | 11:00 | 18:00 | Capabilities showcase |
| Afternoon substance | 14:00 | 21:00 | Imagination / threads |
| Evening engagement | 17:00 | 00:00 | Helpful / repos / tips |
| Night cap | 20:00 | 03:00 | Wild card / Bernard persona |

### Content bank
**File:** `projects/twitter-strategy/content-bank.md`
Pre-written ideas across all 4 categories. Agent picks from unchecked items, marks them done after posting. Refresh regularly with new material from daily work.

## Technical Notes
- **Must use `--http1.1`** for curl to api.x.com — HTTP/2 breaks
- OAuth 1.0a via Python `requests_oauthlib` for write operations
- Bearer token for read-only endpoints
- If app permissions change → must regenerate Access Token + Secret
- Rate limits: be courteous, sleep between batch operations
- **Thread posting**: Space out replies by 3-40 seconds between each post (`sleep $((RANDOM % 38 + 3))` between calls). Never rapid-fire a thread.
- Basic tier: 280 char limit per tweet. Longer takes require threading (yarn style — reply to yourself).
