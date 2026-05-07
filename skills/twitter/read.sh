#!/usr/bin/env bash
# Read recent tweets from the configured X account.
# Usage: bash skills/twitter/read.sh [count]
set -euo pipefail

COUNT="${1:-5}"
ENV_FILE="${OPENCLAW_ENV_FILE:-$HOME/.openclaw/.env}"
BT=$(grep '^X_BEARER_TOKEN=' "$ENV_FILE" | cut -d= -f2-)
USER_ID="${X_USER_ID:-$(grep '^X_USER_ID=' "$ENV_FILE" 2>/dev/null | cut -d= -f2-)}"

if [ -z "$USER_ID" ]; then
  echo "ERROR: X_USER_ID not set (in env or $ENV_FILE)" >&2
  exit 1
fi

curl --http1.1 -s \
  -H "Authorization: Bearer $BT" \
  "https://api.x.com/2/users/${USER_ID}/tweets?max_results=${COUNT}&tweet.fields=created_at,text" \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)
for t in data.get('data', []):
    print(f\"{t['created_at']}  {t['text']}\")
"
