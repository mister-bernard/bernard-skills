#!/usr/bin/env bash
# Create a task-specific agent in Retell AI

set -euo pipefail

RETELL_API_KEY="${RETELL_API_KEY:-$(grep RETELL_API_KEY ~/.openclaw/.env | cut -d= -f2)}"

if [ $# -lt 3 ]; then
  echo "Usage: $0 <agent_name> <language_code> <prompt_text> [voice_id]"
  echo "Example: $0 'Georgian Mechanic' ka-GE 'You are calling a mechanic...'"
  exit 1
fi

AGENT_NAME="$1"
LANGUAGE="$2"
PROMPT="$3"
VOICE_ID="${4:-}"  # Optional, Retell auto-selects if not provided

# Build JSON
JSON=$(cat <<EOF
{
  "agent_name": "$AGENT_NAME",
  "general_prompt": "$PROMPT",
  "language": "$LANGUAGE",
  "responsiveness": 0.7,
  "interruption_sensitivity": 0.5,
  "voice_temperature": 1.0,
  "ambient_sound": "off",
  "general_tools": []
}
EOF
)

if [ -n "$VOICE_ID" ]; then
  JSON=$(echo "$JSON" | jq ". + {\"voice_id\": \"$VOICE_ID\"}")
fi

# Create agent
RESPONSE=$(curl -4 -s -X POST "https://api.retellai.com/v2/create-agent" \
  -H "Authorization: Bearer $RETELL_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$JSON")

# Extract agent_id
AGENT_ID=$(echo "$RESPONSE" | jq -r '.agent_id // empty')

if [ -z "$AGENT_ID" ]; then
  echo "Error creating agent:"
  echo "$RESPONSE" | jq .
  exit 1
fi

echo "$AGENT_ID"
