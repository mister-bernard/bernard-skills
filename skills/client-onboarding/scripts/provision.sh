#!/bin/bash
set -euo pipefail

# Provision client workspace artifacts (local side)
# Usage: bash provision.sh <client_name> [--full-name "Full Name"] [--telegram "@handle"]

WORKSPACE="$HOME/.openclaw/workspace"
MRB_DIR="$HOME/mrb-sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

CLIENT_ID="${1:?Usage: provision.sh <client_name> [--full-name 'Name'] [--telegram '@handle']}"
CLIENT_UPPER=$(echo "$CLIENT_ID" | tr '[:lower:]' '[:upper:]' | tr '-' '_')

shift
FULL_NAME=""
TELEGRAM=""
VPS_IP=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --full-name) FULL_NAME="$2"; shift 2;;
        --telegram) TELEGRAM="$2"; shift 2;;
        --vps-ip) VPS_IP="$2"; shift 2;;
        *) echo "Unknown option: $1"; exit 1;;
    esac
done

echo "🔧 Provisioning client: $CLIENT_ID"
echo "   Prefix: ${CLIENT_UPPER}_"
echo "   Full name: ${FULL_NAME:-TBD}"
echo "   Telegram: ${TELEGRAM:-TBD}"
echo ""

# 1. Create client env file
ENV_FILE="$WORKSPACE/clients/${CLIENT_ID}.env"
if [ -f "$ENV_FILE" ]; then
    echo "⏭️  Client env file already exists: $ENV_FILE"
else
    cat > "$ENV_FILE" << EOF
# Client: $CLIENT_ID ($FULL_NAME)
# Created: $(date -u +%Y-%m-%d)
# All keys prefixed ${CLIENT_UPPER}_

${CLIENT_UPPER}_TELEGRAM_BOT_TOKEN=
${CLIENT_UPPER}_TELEGRAM_BOT_TOKEN_ALT=
${CLIENT_UPPER}_ANTHROPIC_API_KEY=
${CLIENT_UPPER}_VPS_IP=${VPS_IP}
${CLIENT_UPPER}_HETZNER_SERVER_ID=
${CLIENT_UPPER}_SSH_KEY_PATH=~/.ssh/client-${CLIENT_ID}
EOF
    echo "✅ Created env file: $ENV_FILE"
fi

# 2. Create client profile
PROFILE="$WORKSPACE/clients/${CLIENT_ID}.md"
if [ -f "$PROFILE" ]; then
    echo "⏭️  Client profile already exists: $PROFILE"
else
    sed -e "s/<Full Name>/${FULL_NAME:-TBD}/g" \
        -e "s/<name>/${CLIENT_ID}/g" \
        -e "s/<PREFIX>/${CLIENT_UPPER}/g" \
        -e "s/<handle>/${TELEGRAM:-TBD}/g" \
        -e "s/<ip_address>/${VPS_IP:-TBD}/g" \
        -e "s/YYYY-MM-DD/$(date -u +%Y-%m-%d)/g" \
        "$SKILL_DIR/templates/client-profile.md" > "$PROFILE" 2>/dev/null || {
        # Fallback: create minimal profile
        cat > "$PROFILE" << EOF
# Client: ${FULL_NAME:-$CLIENT_ID}

- **Telegram:** ${TELEGRAM:-TBD}
- **Status:** Setup
- **Start date:** $(date -u +%Y-%m-%d)

## Infrastructure
- **VPS IP:** ${VPS_IP:-TBD}
- **Spec:** TBD

## Environment Variables (${CLIENT_UPPER}_ prefix)
See clients/${CLIENT_ID}.env

## Setup Status
- [ ] VPS provisioned
- [ ] OpenClaw installed
- [ ] Bootstrap templates deployed
- [ ] Systemd service configured
- [ ] Firewall (UFW) enabled
- [ ] Anthropic API key configured
- [ ] Telegram bot connected
- [ ] Gateway running
- [ ] Agent identity customized
- [ ] Usage dashboard deployed
- [ ] First heartbeat confirmed
- [ ] Client walkthrough completed

## Billing
- **Payment method:** TBD
- **ETH address:** 0xDf263003D47743B945bB3030915c8794eAf6C637

## Notes
EOF
    }
    echo "✅ Created profile: $PROFILE"
fi

# 3. Create billing JSON
BILLING_DIR="$MRB_DIR/data/clients"
mkdir -p "$BILLING_DIR"
BILLING_FILE="$BILLING_DIR/${CLIENT_ID}.json"
if [ -f "$BILLING_FILE" ]; then
    echo "⏭️  Billing file already exists: $BILLING_FILE"
else
    cat > "$BILLING_FILE" << EOF
{
  "client": "$CLIENT_ID",
  "name": "${FULL_NAME:-$CLIENT_ID}",
  "telegram": "${TELEGRAM:-}",
  "startDate": "$(date -u +%Y-%m-%d)",
  "status": "setup",
  "payments": [],
  "monthlyCosts": {
    "vps": 0,
    "description": "TBD"
  },
  "apiUsage": []
}
EOF
    echo "✅ Created billing file: $BILLING_FILE"
fi

# 4. Create web directory
WEB_DIR="$MRB_DIR/public/client/${CLIENT_ID}"
mkdir -p "$WEB_DIR"
echo "✅ Web directory: $WEB_DIR"

# 5. Update registry
REGISTRY="$WORKSPACE/clients/registry.json"
if [ ! -f "$REGISTRY" ]; then
    echo '{"clients":[]}' > "$REGISTRY"
fi

# Check if client already in registry
if python3 -c "import json; r=json.load(open('$REGISTRY')); exit(0 if any(c['id']=='$CLIENT_ID' for c in r['clients']) else 1)" 2>/dev/null; then
    echo "⏭️  Client already in registry"
else
    python3 << PYEOF
import json
with open('$REGISTRY') as f:
    r = json.load(f)
r['clients'].append({
    "id": "$CLIENT_ID",
    "name": "${FULL_NAME:-$CLIENT_ID}",
    "status": "setup",
    "telegram": "${TELEGRAM:-}",
    "start_date": "$(date -u +%Y-%m-%d)",
    "env_file": "clients/${CLIENT_ID}.env",
    "profile": "clients/${CLIENT_ID}.md",
    "dashboard": "<YOUR_DOMAIN>/client/${CLIENT_ID}/"
})
with open('$REGISTRY', 'w') as f:
    json.dump(r, f, indent=2)
PYEOF
    echo "✅ Added to registry"
fi

# 6. Generate per-client dashboard API key
KEYS_FILE="$MRB_DIR/data/clients/keys.json"
if [ ! -f "$KEYS_FILE" ]; then
    echo '{}' > "$KEYS_FILE"
fi
if python3 -c "import json; k=json.load(open('$KEYS_FILE')); exit(0 if '$CLIENT_ID' in k else 1)" 2>/dev/null; then
    echo "⏭️  Client key already exists"
    CLIENT_DASH_KEY=$(python3 -c "import json; print(json.load(open('$KEYS_FILE'))['$CLIENT_ID'])")
else
    CLIENT_DASH_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(24))")
    python3 << KEYPYEOF
import json
with open('$KEYS_FILE') as f:
    keys = json.load(f)
keys['$CLIENT_ID'] = '$CLIENT_DASH_KEY'
with open('$KEYS_FILE', 'w') as f:
    json.dump(keys, f, indent=2)
KEYPYEOF
    echo "✅ Generated dashboard key: $CLIENT_DASH_KEY"
fi

# 7. Ensure gitignore covers client env files
GITIGNORE="$WORKSPACE/.gitignore"
if ! grep -q "clients/*.env" "$GITIGNORE" 2>/dev/null; then
    echo "clients/*.env" >> "$GITIGNORE"
    echo "✅ Added clients/*.env to .gitignore"
fi

echo ""
echo "========================"
echo "✅ Client $CLIENT_ID provisioned locally"
echo ""
echo "Next steps:"
echo "  1. Fill in env vars: $ENV_FILE"
echo "  2. Provision VPS (Hetzner) and add IP"
echo "  3. Run bootstrap on VPS: ssh root@<ip> 'bash -s' < ~/bernard-bootstrap/provision/provision-vps.sh"
echo "  4. Deploy dashboard: bash skills/client-onboarding/scripts/deploy-dashboard.sh $CLIENT_ID"
echo "  5. Customize agent identity on client VPS"
echo ""
echo "📊 Client dashboard URL:"
echo "   https://<YOUR_DOMAIN>/client/$CLIENT_ID/?key=$CLIENT_DASH_KEY"
