#!/bin/bash
# Leave a Telegram group chat via Bot API
# Usage: leave-group.sh <chat_id>
set -e
CHAT_ID="$1"
if [ -z "$CHAT_ID" ]; then
  echo "Usage: leave-group.sh <chat_id>" >&2
  exit 1
fi
RAW_TOKEN=$(python3 -c "import json; print(json.load(open('$HOME/.openclaw/openclaw.json'))['channels']['telegram']['botToken'])")
# Resolve env var references like ${TELEGRAM_BOT_TOKEN}
if [[ "$RAW_TOKEN" =~ ^\$\{(.+)\}$ ]] || [[ "$RAW_TOKEN" =~ ^\$(.+)$ ]]; then
  VAR_NAME="${BASH_REMATCH[1]}"
  BOT_TOKEN="${!VAR_NAME}"
  if [ -z "$BOT_TOKEN" ]; then
    # Try loading from .env
    BOT_TOKEN=$(grep "^${VAR_NAME}=" "$HOME/.openclaw/.env" 2>/dev/null | cut -d= -f2-)
  fi
  if [ -z "$BOT_TOKEN" ]; then
    echo "ERROR: Could not resolve env var $VAR_NAME" >&2; exit 1
  fi
else
  BOT_TOKEN="$RAW_TOKEN"
fi
RESULT=$(curl -s "https://api.telegram.org/bot${BOT_TOKEN}/leaveChat" -d "chat_id=${CHAT_ID}")
OK=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('ok', False))")
if [ "$OK" = "True" ]; then
  echo "Left group $CHAT_ID"
else
  echo "Failed to leave group $CHAT_ID: $RESULT" >&2
  exit 1
fi
