#!/usr/bin/env bash
# Make a task-specific call via Retell AI

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RETELL_API_KEY="${RETELL_API_KEY:-$(grep RETELL_API_KEY ~/.openclaw/.env | cut -d= -f2)}"
FROM_NUMBER="${RETELL_FROM_NUMBER:-}"

if [ $# -lt 4 ]; then
  echo "Usage: $0 <task_name> <to_number> <language_code> <prompt_text> [cleanup:yes/no]"
  echo ""
  echo "Examples:"
  echo "  $0 'Restaurant Rez' '+33123456789' fr 'Call for dinner reservation...'"
  echo "  $0 'Georgian Mechanic' '+995550009200' ka-GE 'Get paint job quote...'"
  exit 1
fi

TASK_NAME="$1"
TO_NUMBER="$2"
LANGUAGE="$3"
PROMPT="$4"
CLEANUP="${5:-yes}"  # Delete agent after call by default

echo "Creating agent: $TASK_NAME ($LANGUAGE)..."
AGENT_ID=$(bash "$SCRIPT_DIR/retell-create-agent.sh" "$TASK_NAME" "$LANGUAGE" "$PROMPT")

if [ -z "$AGENT_ID" ]; then
  echo "Failed to create agent"
  exit 1
fi

echo "Agent created: $AGENT_ID"
echo "Making call: $FROM_NUMBER → $TO_NUMBER..."

# Make the call
CALL_RESPONSE=$(curl -4 -s -X POST "https://api.retellai.com/v2/create-phone-call" \
  -H "Authorization: Bearer $RETELL_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"from_number\": \"$FROM_NUMBER\",
    \"to_number\": \"$TO_NUMBER\",
    \"override_agent_id\": \"$AGENT_ID\"
  }")

CALL_ID=$(echo "$CALL_RESPONSE" | jq -r '.call_id // empty')

if [ -z "$CALL_ID" ]; then
  echo "Error making call:"
  echo "$CALL_RESPONSE" | jq .
  exit 1
fi

echo "Call initiated: $CALL_ID"
echo "Monitoring call status..."

# Poll for call completion (max 5 minutes)
for i in {1..60}; do
  sleep 5
  CALL_STATUS=$(curl -4 -s "https://api.retellai.com/v2/get-call/$CALL_ID" \
    -H "Authorization: Bearer $RETELL_API_KEY" | jq -r '.call_status')
  
  echo "  Status: $CALL_STATUS"
  
  if [ "$CALL_STATUS" = "ended" ] || [ "$CALL_STATUS" = "error" ]; then
    break
  fi
done

# Get final call details
echo ""
echo "Call complete. Fetching transcript..."
CALL_DETAILS=$(curl -4 -s "https://api.retellai.com/v2/get-call/$CALL_ID" \
  -H "Authorization: Bearer $RETELL_API_KEY")

echo "$CALL_DETAILS" | jq '{
  call_id,
  call_status,
  duration_ms,
  transcript,
  call_analysis,
  public_log_url
}'

# Cleanup agent if requested
if [ "$CLEANUP" = "yes" ]; then
  echo ""
  echo "Cleaning up agent $AGENT_ID..."
  curl -4 -s -X DELETE "https://api.retellai.com/v2/delete-agent/$AGENT_ID" \
    -H "Authorization: Bearer $RETELL_API_KEY" > /dev/null
  echo "Agent deleted"
fi

echo ""
echo "Done!"
