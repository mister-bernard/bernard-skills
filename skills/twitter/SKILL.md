# Twitter / X Skill

Post, read, reply, follow, and engage on X (formerly Twitter) from an OpenClaw agent.

## Account configuration

This skill operates as whichever X account you've put in your `.env`. The
example operator runs it as `@mrb_signal` (Basic tier, $200/mo); fork it,
swap in your own keys, and it runs as your handle.

## Env vars (default file: `~/.openclaw/.env`)

Override the file location with `OPENCLAW_ENV_FILE=/path/to/.env`.

| Var | Purpose |
|---|---|
| `X_CONSUMER_KEY` | API Key (app) |
| `X_COMSUMER_SECRET` | API Secret. ⚠️ **The typo is permanent — it's `COMSUMER` everywhere** |
| `X_ACCESS_TOKEN` | User access token (Read+Write) |
| `X_TOKEN_SECRET` | User access token secret |
| `X_BEARER_TOKEN` | App bearer token (read-only endpoints) |
| `X_USER_ID` | Numeric user id of the account (used for own-timeline reads, follow target) |
| `X_USERNAME` | Handle without `@` (used for building tweet URLs) |

`X_USER_ID` and `X_USERNAME` can also be passed inline as shell env vars
without putting them in the .env file.

## CLI tools

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

## Watchlist + listener

`watchlist.example.json` ships with a generic 30-account starter list
(AI, crypto, aviation, general). Copy it to `watchlist.json` (gitignored)
and curate to your interests.

`listener.py` polls watchlist accounts, scores each tweet for
reply-worthiness, and forwards the top opportunities to your OpenClaw
agent (via `openclaw chat`) to draft replies.

State is persisted in `listener-state.json` (gitignored — start from
`listener-state.example.json`).

### Listener env vars

| Var | Purpose |
|---|---|
| `OPENCLAW_BIN_PATH` | Full path to `openclaw` binary (default: `openclaw`) |
| `TWITTER_DIGEST_FILE` | Where to write the daily-digest markdown |
| `TWITTER_USER_AGENT` | UA string sent on read calls |

### Cost reality (operator note)
On Basic tier, polling 30 accounts every 30 min burned through the spend
cap in two weeks — reads are far more expensive than writes. The example
operator disabled the listener on 2026-03-15 and switched to RSS / Nitter
for ingestion, while continuing to use this skill for posting and
manual replies. If you re-enable, watch your read quota.

## Technical notes

- **Must use `--http1.1`** for curl to api.x.com — HTTP/2 breaks
- OAuth 1.0a via Python `requests_oauthlib` for write operations
- Bearer token for read-only endpoints
- If app permissions change → must regenerate Access Token + Secret
- Rate limits: be courteous, sleep between batch operations
- **Thread posting**: space replies by 3-40 seconds (`sleep $((RANDOM % 38 + 3))`). Never rapid-fire.
- Basic tier: 280 char limit per tweet. Longer takes require threading (yarn-style — reply to yourself).
- Non-ASCII characters (em-dash, smart quotes, arrows) sometimes 403 silently — keep tweet text ASCII when possible.
