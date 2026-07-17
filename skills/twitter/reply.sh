#!/usr/bin/env bash
# Reply to a tweet. Usage: bash skills/twitter/reply.sh <tweet_id> "Reply text"
set -euo pipefail
TWEET_ID="${1:?Usage: reply.sh <tweet_id> \"text\"}"
TEXT="${2:?Usage: reply.sh <tweet_id> \"text\"}"

ENV_FILE="${OPENCLAW_ENV_FILE:-$HOME/.openclaw/.env}"
CK=$(grep '^X_CONSUMER_KEY=' "$ENV_FILE" | cut -d= -f2-)
CS=$(grep '^X_COMSUMER_SECRET=' "$ENV_FILE" | cut -d= -f2-)
AT=$(grep '^X_ACCESS_TOKEN=' "$ENV_FILE" | cut -d= -f2-)
TS=$(grep '^X_TOKEN_SECRET=' "$ENV_FILE" | cut -d= -f2-)
USERNAME="${X_USERNAME:-$(grep '^X_USERNAME=' "$ENV_FILE" 2>/dev/null | cut -d= -f2- || echo i)}"

python3 - "$CK" "$CS" "$AT" "$TS" "$TWEET_ID" "$TEXT" "$USERNAME" <<'PYEOF'
import sys
from requests_oauthlib import OAuth1Session

ck, cs, at, ts, tid, text, username = sys.argv[1:8]
oauth = OAuth1Session(ck, client_secret=cs, resource_owner_key=at, resource_owner_secret=ts)
r = oauth.post("https://api.x.com/2/tweets", json={
    "text": text,
    "reply": {"in_reply_to_tweet_id": tid}
})
if r.status_code in (200, 201):
    data = r.json()
    rid = data["data"]["id"]
    print(f"https://x.com/{username}/status/{rid}")
else:
    print(f"ERROR {r.status_code}: {r.text}", file=sys.stderr)
    sys.exit(1)
PYEOF
