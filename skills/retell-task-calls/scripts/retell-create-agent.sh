#!/usr/bin/env bash
# Create a task-specific agent in Retell AI (current v2 API, 2026-07)
#
# Creates a Retell LLM (claude-4.5-haiku — Retell-hosted; gpt-4o-mini was
# removed from Retell's model list and produced silently-dead agents) and an
# agent wired to it via response_engine, tuned for live-human phone tasks:
#   - voicemail_option: hangup by default (Retell waits for beep detection;
#     pass RETELL_VOICEMAIL_TEXT env to leave a message after the beep instead)
#   - responsiveness 1 / interruption_sensitivity 0.9: fast turn-taking,
#     instant re-delivery when asked to repeat
#   - start_speaker user: wait out the callee's greeting instead of talking over it
#
# Echoes AGENT_ID on stdout. The paired LLM is left in place; callers that
# delete the agent should also delete the LLM (delete-retell-llm/<llm_id>);
# the llm_id is echoed to stderr as "llm_id: ..." for that purpose.

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
VOICE_ID="${4:-11labs-Brian}"
MODEL="${RETELL_MODEL:-claude-4.5-haiku}"

API="https://api.retellai.com"
AUTH="Authorization: Bearer $RETELL_API_KEY"
CT="Content-Type: application/json"

# 1. Retell LLM (holds the prompt + model)
LLM_BODY=$(jq -n --arg m "$MODEL" --arg p "$PROMPT" \
  '{model: $m, general_prompt: $p, start_speaker: "user"}')
LLM_RESPONSE=$(curl -4 -s -X POST "$API/create-retell-llm" -H "$AUTH" -H "$CT" -d "$LLM_BODY")
LLM_ID=$(echo "$LLM_RESPONSE" | jq -r '.llm_id // empty')
if [ -z "$LLM_ID" ]; then
  echo "Error creating Retell LLM:" >&2
  echo "$LLM_RESPONSE" | jq . >&2
  exit 1
fi
echo "llm_id: $LLM_ID" >&2

# 2. Agent wired to the LLM
JSON=$(jq -n --arg n "$AGENT_NAME" --arg l "$LANGUAGE" --arg llm "$LLM_ID" \
  --arg v "$VOICE_ID" --arg vm "${RETELL_VOICEMAIL_TEXT:-}" '
  {
    agent_name: $n,
    language: $l,
    voice_id: $v,
    response_engine: {type: "retell-llm", llm_id: $llm},
    responsiveness: 1,
    interruption_sensitivity: 0.9,
    enable_backchannel: true,
    backchannel_frequency: 0.6,
    begin_message_delay_ms: 700,
    reminder_trigger_ms: 8000,
    reminder_max_count: 2,
    normalize_for_speech: true,
    end_call_after_silence_ms: 30000,
    max_call_duration_ms: 300000
  }
  + (if $vm != "" then {voicemail_option: {action: {type: "static_text", text: $vm}}}
     else {voicemail_option: {action: {type: "hangup"}}} end)')

RESPONSE=$(curl -4 -s -X POST "$API/create-agent" -H "$AUTH" -H "$CT" -d "$JSON")
AGENT_ID=$(echo "$RESPONSE" | jq -r '.agent_id // empty')

if [ -z "$AGENT_ID" ]; then
  echo "Error creating agent:" >&2
  echo "$RESPONSE" | jq . >&2
  curl -4 -s -X DELETE "$API/delete-retell-llm/$LLM_ID" -H "$AUTH" > /dev/null 2>&1
  exit 1
fi

echo "$AGENT_ID"
