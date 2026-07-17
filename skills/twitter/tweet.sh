#!/usr/bin/env bash
# Post a tweet from the configured X account.
# Usage: bash skills/twitter/tweet.sh "Tweet text"
set -euo pipefail

TEXT="${1:?Usage: tweet.sh \"text\"}"

# Load keys from .env (handles the COMSUMER typo)
ENV_FILE="${OPENCLAW_ENV_FILE:-$HOME/.openclaw/.env}"
CK=$(grep '^X_CONSUMER_KEY=' "$ENV_FILE" | cut -d= -f2-)
CS=$(grep '^X_COMSUMER_SECRET=' "$ENV_FILE" | cut -d= -f2-)
AT=$(grep '^X_ACCESS_TOKEN=' "$ENV_FILE" | cut -d= -f2-)
TS=$(grep '^X_TOKEN_SECRET=' "$ENV_FILE" | cut -d= -f2-)
USERNAME="${X_USERNAME:-$(grep '^X_USERNAME=' "$ENV_FILE" 2>/dev/null | cut -d= -f2- || echo i)}"

python3 - "$CK" "$CS" "$AT" "$TS" "$TEXT" "$USERNAME" <<'PYEOF'
import sys
from requests_oauthlib import OAuth1Session

ck, cs, at, ts, text, username = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6]
oauth = OAuth1Session(ck, client_secret=cs, resource_owner_key=at, resource_owner_secret=ts)
r = oauth.post("https://api.x.com/2/tweets", json={"text": text})

if r.status_code in (200, 201):
    data = r.json()
    tid = data["data"]["id"]
    print(f"https://x.com/{username}/status/{tid}")
else:
    print(f"ERROR {r.status_code}: {r.text}", file=sys.stderr)
    sys.exit(1)
PYEOF
