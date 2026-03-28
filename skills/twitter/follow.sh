#!/usr/bin/env bash
# Follow a user on X. Usage: bash skills/twitter/follow.sh <username>
set -euo pipefail
USERNAME="${1:?Usage: follow.sh <username>}"

ENV_FILE="$HOME/.openclaw/.env"
CK=$(grep '^X_CONSUMER_KEY=' "$ENV_FILE" | cut -d= -f2-)
CS=$(grep '^X_COMSUMER_SECRET=' "$ENV_FILE" | cut -d= -f2-)
AT=$(grep '^X_ACCESS_TOKEN=' "$ENV_FILE" | cut -d= -f2-)
TS=$(grep '^X_TOKEN_SECRET=' "$ENV_FILE" | cut -d= -f2-)
BT=$(grep '^X_BEARER_TOKEN=' "$ENV_FILE" | cut -d= -f2-)

# Resolve username to ID
USER_ID=$(curl --http1.1 -s -H "Authorization: Bearer $BT" \
  "https://api.x.com/2/users/by/username/$USERNAME" | python3 -c "
import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('id',''))" 2>/dev/null)

if [ -z "$USER_ID" ]; then
  echo "ERROR: Could not resolve @$USERNAME" >&2; exit 1
fi

# Follow
python3 - "$CK" "$CS" "$AT" "$TS" "$USER_ID" "$USERNAME" <<'PYEOF'
import sys
sys.path.insert(0, '/home/openclaw/.local/lib/python3.12/site-packages')
from requests_oauthlib import OAuth1Session
import json

ck, cs, at, ts, uid, uname = sys.argv[1:7]
MY_ID = "2027171957880549376"
oauth = OAuth1Session(ck, client_secret=cs, resource_owner_key=at, resource_owner_secret=ts)
r = oauth.post(f"https://api.x.com/2/users/{MY_ID}/following", json={"target_user_id": uid})
if r.status_code in (200, 201):
    data = r.json()
    if data.get("data", {}).get("following"):
        print(f"✅ Now following @{uname}")
    else:
        print(f"⏳ Follow request sent to @{uname} (may be pending)")
else:
    print(f"ERROR {r.status_code}: {r.text}", file=sys.stderr)
    sys.exit(1)
PYEOF
