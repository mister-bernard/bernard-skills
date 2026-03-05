#!/bin/bash
set -euo pipefail

# Pull token usage from a client VPS and update billing records
# Usage: bash usage-sync.sh <client_name> [--since YYYY-MM-DD]
#
# Reads OpenClaw session JSONL files on the client VPS, aggregates
# token counts per day, and stores in our billing JSON.

WORKSPACE="$HOME/.openclaw/workspace"
MRB_DIR="$HOME/mrb-sh"
CLIENT_ID="${1:?Usage: usage-sync.sh <client_name> [--since YYYY-MM-DD]}"
CLIENT_UPPER=$(echo "$CLIENT_ID" | tr '[:lower:]' '[:upper:]' | tr '-' '_')

shift
SINCE=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --since) SINCE="$2"; shift 2;;
        *) echo "Unknown: $1"; exit 1;;
    esac
done

# Default: last 30 days
SINCE="${SINCE:-$(date -d '30 days ago' +%Y-%m-%d 2>/dev/null || date -v-30d +%Y-%m-%d)}"

# Load client env
ENV_FILE="$WORKSPACE/clients/${CLIENT_ID}.env"
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ Client env not found: $ENV_FILE"
    exit 1
fi

VPS_IP=$(grep "${CLIENT_UPPER}_VPS_IP" "$ENV_FILE" | cut -d= -f2)
SSH_KEY=$(grep "${CLIENT_UPPER}_SSH_KEY_PATH" "$ENV_FILE" | cut -d= -f2 || echo "")
SSH_KEY="${SSH_KEY:-$HOME/.ssh/client-${CLIENT_ID}}"
SSH_KEY="${SSH_KEY/#\~/$HOME}"

SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10"
if [ -f "$SSH_KEY" ]; then
    SSH_OPTS="$SSH_OPTS -i $SSH_KEY"
fi

echo "📊 Syncing usage for $CLIENT_ID ($VPS_IP) since $SINCE"

# Pull usage data from client VPS via a remote Python script
REMOTE_SCRIPT=$(cat << 'REMOTEPY'
import json, glob, os, sys
from datetime import datetime

since = sys.argv[1] if len(sys.argv) > 1 else "2020-01-01"
sessions_dir = os.path.expanduser("~/.openclaw/sessions")
usage = {}  # {date: {input_tokens, output_tokens, sessions, requests}}

for jsonl_path in glob.glob(os.path.join(sessions_dir, "*.jsonl")):
    try:
        with open(jsonl_path) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                except json.JSONDecodeError:
                    continue
                
                # Look for usage data in assistant messages
                ts = entry.get("timestamp", entry.get("ts", ""))
                if not ts:
                    continue
                
                # Extract date
                date_str = ts[:10]  # YYYY-MM-DD
                if date_str < since:
                    continue
                
                if date_str not in usage:
                    usage[date_str] = {"input_tokens": 0, "output_tokens": 0, "requests": 0, "sessions": set()}
                
                # Token usage from various possible formats
                u = entry.get("usage", {})
                if u:
                    usage[date_str]["input_tokens"] += u.get("input_tokens", u.get("prompt_tokens", 0))
                    usage[date_str]["output_tokens"] += u.get("output_tokens", u.get("completion_tokens", 0))
                    usage[date_str]["requests"] += 1
                
                # Track unique sessions
                session = os.path.basename(jsonl_path).replace(".jsonl", "")
                usage[date_str]["sessions"].add(session)
    except Exception as e:
        continue

# Convert sets to counts for JSON serialization
result = []
for date_str in sorted(usage.keys()):
    d = usage[date_str]
    result.append({
        "date": date_str,
        "input_tokens": d["input_tokens"],
        "output_tokens": d["output_tokens"],
        "total_tokens": d["input_tokens"] + d["output_tokens"],
        "requests": d["requests"],
        "sessions": len(d["sessions"])
    })

print(json.dumps(result))
REMOTEPY
)

# Execute remotely
USAGE_JSON=$(ssh $SSH_OPTS "openclaw@${VPS_IP}" "python3 -c '$(echo "$REMOTE_SCRIPT" | sed "s/'/'\\\\''/g")' '$SINCE'" 2>/dev/null || echo "[]")

if [ "$USAGE_JSON" = "[]" ] || [ -z "$USAGE_JSON" ]; then
    echo "⚠️  No usage data returned (VPS may be unreachable or no sessions yet)"
    exit 0
fi

# Update billing JSON
BILLING_FILE="$MRB_DIR/data/clients/${CLIENT_ID}.json"
if [ ! -f "$BILLING_FILE" ]; then
    echo "❌ Billing file not found: $BILLING_FILE"
    exit 1
fi

python3 << PYEOF
import json, sys

with open("$BILLING_FILE") as f:
    billing = json.load(f)

usage_data = json.loads('''$USAGE_JSON''')

# Replace apiUsage with fresh data
billing["apiUsage"] = usage_data

# Calculate totals
total_input = sum(d["input_tokens"] for d in usage_data)
total_output = sum(d["output_tokens"] for d in usage_data)
total_tokens = total_input + total_output
total_requests = sum(d["requests"] for d in usage_data)

# Estimate cost (Sonnet pricing: $3/M input, $15/M output)
est_cost = (total_input * 3.0 / 1_000_000) + (total_output * 15.0 / 1_000_000)

billing["usageSummary"] = {
    "period": "$SINCE to $(date +%Y-%m-%d)",
    "totalInputTokens": total_input,
    "totalOutputTokens": total_output,
    "totalTokens": total_tokens,
    "totalRequests": total_requests,
    "estimatedCostUSD": round(est_cost, 2)
}

with open("$BILLING_FILE", "w") as f:
    json.dump(billing, f, indent=2)

print(f"✅ Usage synced: {len(usage_data)} days, {total_tokens:,} tokens, ~\${est_cost:.2f}")
for d in usage_data[-5:]:  # Last 5 days
    print(f"   {d['date']}: {d['total_tokens']:>10,} tokens ({d['requests']} reqs, {d['sessions']} sessions)")
PYEOF
