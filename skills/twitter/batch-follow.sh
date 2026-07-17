#!/usr/bin/env bash
# Follow all accounts in watchlist.json (or watchlist.example.json as fallback)
# Usage: bash skills/twitter/batch-follow.sh [--dry-run]
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
DRY_RUN="${1:-}"

WATCHLIST="$SKILL_DIR/watchlist.json"
if [ ! -f "$WATCHLIST" ]; then
    WATCHLIST="$SKILL_DIR/watchlist.example.json"
    echo "(no watchlist.json found — using watchlist.example.json as fallback)"
fi

USERNAMES=$(python3 -c "
import json
data = json.load(open('$WATCHLIST'))
for a in data['accounts']:
    print(a['username'])
")

COUNT=0
TOTAL=$(echo "$USERNAMES" | wc -l)

while IFS= read -r username; do
    COUNT=$((COUNT + 1))
    echo "[$COUNT/$TOTAL] @$username"
    if [ "$DRY_RUN" = "--dry-run" ]; then
        echo "  (dry run — skipping)"
    else
        bash "$SKILL_DIR/follow.sh" "$username" 2>&1 | sed 's/^/  /'
        sleep 2  # Rate limit courtesy
    fi
done <<< "$USERNAMES"

echo "Done. Followed $COUNT accounts."
