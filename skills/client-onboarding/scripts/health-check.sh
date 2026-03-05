#!/bin/bash
set -uo pipefail

# Health check for a client's OpenClaw VPS
# Usage: bash health-check.sh <client_name> [--json]

WORKSPACE="$HOME/.openclaw/workspace"
CLIENT_ID="${1:?Usage: health-check.sh <client_name> [--json]}"
CLIENT_UPPER=$(echo "$CLIENT_ID" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
JSON_MODE="${2:-}"

ENV_FILE="$WORKSPACE/clients/${CLIENT_ID}.env"
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ Client env file not found: $ENV_FILE"
    exit 1
fi

# Read VPS IP
VPS_IP=$(grep "${CLIENT_UPPER}_VPS_IP" "$ENV_FILE" | cut -d= -f2)
if [ -z "$VPS_IP" ]; then
    echo "❌ No VPS IP found for $CLIENT_ID"
    exit 1
fi

SSH_KEY=$(grep "${CLIENT_UPPER}_SSH_KEY_PATH" "$ENV_FILE" | cut -d= -f2 || echo "")
SSH_OPTS="-o ConnectTimeout=5 -o StrictHostKeyChecking=no"
[ -n "$SSH_KEY" ] && [ -f "${SSH_KEY/#\~/$HOME}" ] && SSH_OPTS="$SSH_OPTS -i ${SSH_KEY/#\~/$HOME}"

checks_passed=0
checks_total=0
results=""

check() {
    local name="$1"
    local result="$2"
    local status="$3" # ok, warn, fail
    checks_total=$((checks_total + 1))
    [ "$status" = "ok" ] && checks_passed=$((checks_passed + 1))
    
    if [ "$JSON_MODE" = "--json" ]; then
        results="${results}{\"check\":\"$name\",\"result\":\"$result\",\"status\":\"$status\"},"
    else
        case $status in
            ok)   echo "  ✅ $name: $result";;
            warn) echo "  ⚠️  $name: $result";;
            fail) echo "  ❌ $name: $result";;
        esac
    fi
}

[ "$JSON_MODE" != "--json" ] && echo "🔍 Health check: $CLIENT_ID ($VPS_IP)"
[ "$JSON_MODE" != "--json" ] && echo ""

# 1. SSH reachable
if ssh $SSH_OPTS "openclaw@$VPS_IP" 'echo ok' &>/dev/null; then
    check "SSH" "reachable" "ok"
else
    check "SSH" "unreachable" "fail"
    [ "$JSON_MODE" = "--json" ] && echo "{\"client\":\"$CLIENT_ID\",\"ip\":\"$VPS_IP\",\"checks\":[${results%,}],\"passed\":$checks_passed,\"total\":$checks_total}"
    [ "$JSON_MODE" != "--json" ] && echo "" && echo "❌ SSH failed — cannot run further checks"
    exit 1
fi

# 2. Gateway running
GW_STATUS=$(ssh $SSH_OPTS "openclaw@$VPS_IP" 'openclaw gateway status 2>/dev/null | grep "Runtime:" | head -1' 2>/dev/null || echo "unknown")
if echo "$GW_STATUS" | grep -q "running"; then
    check "Gateway" "running" "ok"
else
    check "Gateway" "$GW_STATUS" "fail"
fi

# 3. Disk usage
DISK_PCT=$(ssh $SSH_OPTS "openclaw@$VPS_IP" "df -h / | tail -1 | awk '{print \$5}'" 2>/dev/null || echo "unknown")
DISK_NUM=${DISK_PCT//%/}
if [ "$DISK_NUM" -lt 80 ] 2>/dev/null; then
    check "Disk" "$DISK_PCT used" "ok"
elif [ "$DISK_NUM" -lt 90 ] 2>/dev/null; then
    check "Disk" "$DISK_PCT used" "warn"
else
    check "Disk" "$DISK_PCT used" "fail"
fi

# 4. Memory
MEM_PCT=$(ssh $SSH_OPTS "openclaw@$VPS_IP" "free | awk '/Mem/{printf(\"%d\", \$3/\$2*100)}'" 2>/dev/null || echo "unknown")
if [ "$MEM_PCT" -lt 80 ] 2>/dev/null; then
    check "Memory" "${MEM_PCT}% used" "ok"
elif [ "$MEM_PCT" -lt 90 ] 2>/dev/null; then
    check "Memory" "${MEM_PCT}% used" "warn"
else
    check "Memory" "${MEM_PCT}% used" "fail"
fi

# 5. Uptime
UPTIME=$(ssh $SSH_OPTS "openclaw@$VPS_IP" 'uptime -p' 2>/dev/null || echo "unknown")
check "Uptime" "$UPTIME" "ok"

# 6. OpenClaw version
OC_VER=$(ssh $SSH_OPTS "openclaw@$VPS_IP" 'openclaw --version 2>/dev/null || echo unknown' 2>/dev/null)
check "OpenClaw" "v$OC_VER" "ok"

# Output
if [ "$JSON_MODE" = "--json" ]; then
    echo "{\"client\":\"$CLIENT_ID\",\"ip\":\"$VPS_IP\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"checks\":[${results%,}],\"passed\":$checks_passed,\"total\":$checks_total}"
else
    echo ""
    echo "Result: $checks_passed/$checks_total checks passed"
fi
