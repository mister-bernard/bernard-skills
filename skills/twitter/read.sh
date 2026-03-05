#!/usr/bin/env bash
# Read recent tweets from @mrb_signal
# Usage: bash skills/twitter/read.sh [count]
set -euo pipefail

COUNT="${1:-5}"
BT=$(grep '^X_BEARER_TOKEN=' "$HOME/.openclaw/.env" | cut -d= -f2-)

curl --http1.1 -s \
  -H "Authorization: Bearer $BT" \
  "https://api.x.com/2/users/2027171957880549376/tweets?max_results=${COUNT}&tweet.fields=created_at,text" \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)
for t in data.get('data', []):
    print(f\"{t['created_at']}  {t['text']}\")
"
