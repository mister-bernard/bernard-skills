#!/bin/bash
set -uo pipefail

# Health check ALL active clients
# Usage: bash health-check-all.sh [--json]

WORKSPACE="$HOME/.openclaw/workspace"
REGISTRY="$WORKSPACE/clients/registry.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JSON_MODE="${1:-}"

if [ ! -f "$REGISTRY" ]; then
    echo "❌ No registry found at $REGISTRY"
    exit 1
fi

CLIENTS=$(python3 -c "
import json
r = json.load(open('$REGISTRY'))
for c in r['clients']:
    if c.get('status') in ('active', 'setup'):
        print(c['id'])
")

if [ -z "$CLIENTS" ]; then
    echo "No active clients found"
    exit 0
fi

[ "$JSON_MODE" != "--json" ] && echo "🔍 Health check: all active clients"
[ "$JSON_MODE" != "--json" ] && echo ""

RESULTS="["
for client in $CLIENTS; do
    if [ "$JSON_MODE" = "--json" ]; then
        result=$(bash "$SCRIPT_DIR/health-check.sh" "$client" --json 2>/dev/null || echo "{\"client\":\"$client\",\"error\":\"check failed\"}")
        RESULTS="${RESULTS}${result},"
    else
        bash "$SCRIPT_DIR/health-check.sh" "$client" 2>/dev/null || echo "  ❌ $client: check failed"
        echo ""
    fi
done

if [ "$JSON_MODE" = "--json" ]; then
    echo "${RESULTS%,}]"
fi
