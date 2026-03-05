#!/usr/bin/env bash
# BIOS Research CLI helper
set -euo pipefail

# Load API key
BIOS_API_KEY=$(grep -m1 'BIOS_API_KEY=' ~/.openclaw/.env | cut -d= -f2 | tr -d '"' | tr -d "'")
BASE="https://api.ai.bio.xyz"
AUTH="Authorization: Bearer $BIOS_API_KEY"

cmd="${1:-help}"
shift || true

case "$cmd" in
  search)
    msg="${1:?Usage: bios.sh search \"your research question\" [mode]}"
    mode="${2:-semi-autonomous}"
    curl -s -X POST "$BASE/deep-research/start" \
      -H "$AUTH" \
      -d "message=$msg" \
      -d "researchMode=$mode" | python3 -m json.tool
    ;;

  status)
    id="${1:?Usage: bios.sh status <conversation_id>}"
    curl -s "$BASE/deep-research/$id" -H "$AUTH" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f\"Status: {d['status']}\")
msgs = d.get('messages', [])
print(f\"Messages: {len(msgs)}\")
state = d.get('state', {})
for k in ['objective', 'hypotheses', 'discoveries', 'insights']:
    v = state.get(k)
    if v:
        print(f'\n## {k.title()}')
        if isinstance(v, list):
            for item in v[:5]: print(f'  - {str(item)[:200]}')
        else:
            print(f'  {str(v)[:500]}')
"
    ;;

  detail)
    id="${1:?Usage: bios.sh detail <conversation_id>}"
    curl -s "$BASE/deep-research/$id" -H "$AUTH" | python3 -m json.tool
    ;;

  list)
    limit="${1:-10}"
    curl -s "$BASE/deep-research?limit=$limit" -H "$AUTH" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for c in d.get('data', []):
    title = c.get('title') or '(untitled)'
    print(f\"{c['id'][:12]}...  {c.get('updatedAt','')[:16]}  {title}\")
print(f\"\nTotal shown: {len(d.get('data',[]))}, hasMore: {d.get('hasMore', False)}\")
"
    ;;

  literature)
    query="${1:?Usage: bios.sh literature \"search query\"}"
    curl -s -X POST "$BASE/agents/literature/query" \
      -H "$AUTH" \
      -H "Content-Type: application/json" \
      -d "{\"query\": \"$query\"}" | python3 -m json.tool
    ;;

  upload)
    file="${1:?Usage: bios.sh upload <filepath>}"
    curl -s -X POST "$BASE/files/upload" \
      -H "$AUTH" \
      -F "file=@$file" | python3 -m json.tool
    ;;

  health)
    curl -s "$BASE/health" | python3 -m json.tool
    ;;

  help|*)
    echo "BIOS Research CLI"
    echo ""
    echo "Usage: bios.sh <command> [args]"
    echo ""
    echo "Commands:"
    echo "  search \"query\" [mode]    Start research (modes: steering|semi-autonomous|fully-autonomous)"
    echo "  status <conv_id>         Check research status + key findings"
    echo "  detail <conv_id>         Full conversation JSON"
    echo "  list [limit]             List recent sessions"
    echo "  literature \"query\"       Literature-only search"
    echo "  upload <file>            Upload file for analysis"
    echo "  health                   API health check"
    ;;
esac
