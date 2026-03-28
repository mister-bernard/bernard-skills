#!/bin/bash
# Make an on-demand Retell AI call with auto-generated prompt

set -e

RETELL_API_KEY="${RETELL_API_KEY:-$(grep RETELL_API_KEY ~/.openclaw/.env | cut -d= -f2-)}"
FROM_NUMBER="+1XXXXXXXXXX"

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 <to_number> <task_description>"
  echo ""
  echo "Example:"
  echo "  $0 '+12085551234' 'Call to demonstrate AI assistant capabilities'"
  exit 1
fi

TO_NUMBER="$1"
TASK_DESC="$2"

echo "=== Creating Retell LLM with conversational prompt ==="

# Generate conversational prompt
PROMPT="You are Mr. Bernard's AI assistant calling ${TO_NUMBER}.

YOUR GOAL: ${TASK_DESC}

HOW TO HAVE THE CONVERSATION:
1. When someone answers, say: \"Hi, this is Mr. Bernard's assistant. Is this a good time to talk?\"
   Then STOP and wait for them to respond.
2. If they say yes, explain briefly: \"${TASK_DESC}\"
   Then STOP and wait.
3. Answer any questions they have naturally.
4. When done, thank them and say goodbye.

IMPORTANT:
- Speak ONE sentence at a time, then wait for a response.
- Be warm, professional, and conversational.
- If they seem busy, offer to call back later.
- If you reach voicemail, leave a brief message."

# Create LLM
LLM_RESPONSE=$(curl -s -X POST "https://api.retellai.com/create-retell-llm" \
  -H "Authorization: Bearer $RETELL_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"gpt-4o-mini\",\"general_prompt\":$(echo "$PROMPT" | jq -Rs .)}")

LLM_ID=$(echo "$LLM_RESPONSE" | jq -r '.llm_id')

if [ -z "$LLM_ID" ] || [ "$LLM_ID" = "null" ]; then
  echo "❌ Failed to create LLM:"
  echo "$LLM_RESPONSE" | jq .
  exit 1
fi

echo "✓ LLM created: $LLM_ID"

echo ""
echo "=== Creating temporary agent ==="

AGENT_RESPONSE=$(curl -s -X POST "https://api.retellai.com/create-agent" \
  -H "Authorization: Bearer $RETELL_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"agent_name\":\"OnDemand - $(date +%s)\",
    \"voice_id\":\"11labs-Brian\",
    \"response_engine\":{
      \"type\":\"retell-llm\",
      \"llm_id\":\"$LLM_ID\"
    },
    \"responsiveness\":0.6,
    \"interruption_sensitivity\":0.5
  }")

AGENT_ID=$(echo "$AGENT_RESPONSE" | jq -r '.agent_id')

if [ -z "$AGENT_ID" ] || [ "$AGENT_ID" = "null" ]; then
  echo "❌ Failed to create agent:"
  echo "$AGENT_RESPONSE" | jq .
  exit 1
fi

echo "✓ Agent created: $AGENT_ID"

echo ""
echo "=== Placing call ==="

CALL_RESPONSE=$(curl -s -X POST "https://api.retellai.com/v2/create-phone-call" \
  -H "Authorization: Bearer $RETELL_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"from_number\":\"$FROM_NUMBER\",
    \"to_number\":\"$TO_NUMBER\",
    \"override_agent_id\":\"$AGENT_ID\"
  }")

CALL_ID=$(echo "$CALL_RESPONSE" | jq -r '.call_id')

if [ -z "$CALL_ID" ] || [ "$CALL_ID" = "null" ]; then
  echo "❌ Failed to place call:"
  echo "$CALL_RESPONSE" | jq .
  exit 1
fi

echo "✓ Call initiated: $CALL_ID"
echo ""
echo "📞 Calling $TO_NUMBER..."
echo ""
echo "Waiting for call to complete (checking every 10s)..."

# Poll for call completion
for i in {1..60}; do
  sleep 10
  
  CALL_STATUS=$(curl -s "https://api.retellai.com/v2/get-call/$CALL_ID" \
    -H "Authorization: Bearer $RETELL_API_KEY")
  
  END_TIMESTAMP=$(echo "$CALL_STATUS" | jq -r '.end_timestamp // empty')
  
  if [ -n "$END_TIMESTAMP" ]; then
    echo ""
    echo "=== Call completed ==="
    echo ""
    
    # Extract key info
    DURATION=$(echo "$CALL_STATUS" | jq -r '.call_analysis.call_summary.duration_seconds // "N/A"')
    REASON=$(echo "$CALL_STATUS" | jq -r '.disconnection_reason // "unknown"')
    TRANSCRIPT=$(echo "$CALL_STATUS" | jq -r '.transcript // "No transcript available"')
    
    echo "Duration: ${DURATION}s"
    echo "Disconnect reason: $REASON"
    echo ""
    echo "Transcript:"
    echo "$TRANSCRIPT"
    echo ""
    
    # Save full response
    echo "$CALL_STATUS" | jq . > "/tmp/retell-call-$CALL_ID.json"
    echo "Full call data saved to: /tmp/retell-call-$CALL_ID.json"
    
    break
  fi
  
  echo -n "."
done

echo ""
echo ""
echo "=== Cleanup (optional) ==="
echo "Agent ID: $AGENT_ID"
echo "LLM ID: $LLM_ID"
echo ""
echo "To delete:"
echo "  curl -X DELETE https://api.retellai.com/delete-agent/$AGENT_ID -H 'Authorization: Bearer $RETELL_API_KEY'"
echo "  curl -X DELETE https://api.retellai.com/delete-retell-llm/$LLM_ID -H 'Authorization: Bearer $RETELL_API_KEY'"
