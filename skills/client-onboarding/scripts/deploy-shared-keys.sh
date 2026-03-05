#!/bin/bash
set -euo pipefail

# Deploy our shared Anthropic auth profiles to a client VPS
# Usage: bash deploy-shared-keys.sh <client_name>
#
# Sets up both our Anthropic subscriptions (default + backup) on the client's
# OpenClaw instance with proper failover. If the client also has their own key,
# it gets highest priority.

WORKSPACE="$HOME/.openclaw/workspace"
CLIENT_ID="${1:?Usage: deploy-shared-keys.sh <client_name>}"
CLIENT_UPPER=$(echo "$CLIENT_ID" | tr '[:lower:]' '[:upper:]' | tr '-' '_')

# Load client env
ENV_FILE="$WORKSPACE/clients/${CLIENT_ID}.env"
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ Client env file not found: $ENV_FILE"
    exit 1
fi

# Get VPS IP
VPS_IP=$(grep "${CLIENT_UPPER}_VPS_IP" "$ENV_FILE" | cut -d= -f2)
if [ -z "$VPS_IP" ]; then
    echo "❌ No VPS IP found in $ENV_FILE"
    exit 1
fi

# Get SSH key path (default: ~/.ssh/client-<name>)
SSH_KEY=$(grep "${CLIENT_UPPER}_SSH_KEY_PATH" "$ENV_FILE" | cut -d= -f2 || echo "")
SSH_KEY="${SSH_KEY:-$HOME/.ssh/client-${CLIENT_ID}}"
# Expand ~
SSH_KEY="${SSH_KEY/#\~/$HOME}"

SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10"
if [ -f "$SSH_KEY" ]; then
    SSH_OPTS="$SSH_OPTS -i $SSH_KEY"
fi

echo "🔑 Deploying shared Anthropic keys to $CLIENT_ID ($VPS_IP)"

# Load our keys from main .env
OUR_DEFAULT_KEY=$(grep "^ANTHROPIC_API_KEY=" "$HOME/.openclaw/.env" | head -1 | cut -d= -f2)
OUR_BACKUP_KEY=$(grep "^ANTHROPIC_BACKUP_API_KEY=" "$HOME/.openclaw/.env" | head -1 | cut -d= -f2)

# Check if client has their own key
CLIENT_KEY=$(grep "${CLIENT_UPPER}_ANTHROPIC_API_KEY" "$ENV_FILE" | cut -d= -f2 || echo "")

if [ -z "$OUR_BACKUP_KEY" ]; then
    echo "⚠️  No ANTHROPIC_BACKUP_API_KEY in our .env — using default key only"
fi

# Build the auth profiles JSON for client's openclaw.json
# Priority: client's own key (if any) > our backup > our default
cat > /tmp/deploy-keys-${CLIENT_ID}.py << 'PYEOF'
import json
import sys
import subprocess

vps_ip = sys.argv[1]
ssh_opts = sys.argv[2]
client_key = sys.argv[3] if len(sys.argv) > 3 else ""
our_backup = sys.argv[4] if len(sys.argv) > 4 else ""
our_default = sys.argv[5] if len(sys.argv) > 5 else ""

# Read current openclaw.json from client VPS
result = subprocess.run(
    f"ssh {ssh_opts} openclaw@{vps_ip} cat ~/.openclaw/openclaw.json",
    shell=True, capture_output=True, text=True
)
if result.returncode != 0:
    print(f"❌ Failed to read openclaw.json: {result.stderr}")
    sys.exit(1)

config = json.loads(result.stdout)

# Build auth profiles
profiles = {}
auth_order = []

if client_key:
    profiles["client"] = {"apiKey": client_key}
    auth_order.append("client")

if our_backup:
    profiles["shared-backup"] = {"apiKey": our_backup}
    auth_order.append("shared-backup")

if our_default:
    profiles["shared-default"] = {"apiKey": our_default}
    auth_order.append("shared-default")

# Update config
if "anthropic" not in config:
    config["anthropic"] = {}
config["anthropic"]["profiles"] = profiles
config["anthropic"]["authOrder"] = auth_order

# Also set failover to Sonnet only (never free models)
if "agents" not in config:
    config["agents"] = {}
if "defaults" not in config["agents"]:
    config["agents"]["defaults"] = {}
config["agents"]["defaults"]["fallbacks"] = ["anthropic/claude-sonnet-4-5"]

new_json = json.dumps(config, indent=2)

# Write back
proc = subprocess.run(
    f"ssh {ssh_opts} openclaw@{vps_ip} 'cat > ~/.openclaw/openclaw.json'",
    shell=True, input=new_json, capture_output=True, text=True
)
if proc.returncode != 0:
    print(f"❌ Failed to write openclaw.json: {proc.stderr}")
    sys.exit(1)

print(f"✅ Auth profiles deployed:")
for i, name in enumerate(auth_order):
    priority = "← primary" if i == 0 else ""
    key_preview = profiles[name]["apiKey"][:12] + "..."
    print(f"   {i+1}. {name}: {key_preview} {priority}")
print(f"   Failover: anthropic/claude-sonnet-4-5")
PYEOF

python3 /tmp/deploy-keys-${CLIENT_ID}.py \
    "$VPS_IP" \
    "$SSH_OPTS" \
    "${CLIENT_KEY:-}" \
    "${OUR_BACKUP_KEY:-}" \
    "${OUR_DEFAULT_KEY:-}"

rm -f /tmp/deploy-keys-${CLIENT_ID}.py

echo ""
echo "⚠️  Restart gateway on client VPS to apply:"
echo "   ssh $SSH_OPTS openclaw@$VPS_IP 'openclaw gateway restart'"
