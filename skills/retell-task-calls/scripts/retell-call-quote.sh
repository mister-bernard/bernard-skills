#!/usr/bin/env bash
# Get service quote via phone call

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ $# -lt 5 ]; then
  echo "Usage: $0 <business_name> <phone> <language> <service> <customer_name> [goal]"
  echo ""
  echo "Examples:"
  echo "  $0 'Auto Body Shop' '+995550009200' ka-GE 'full car paint job' 'Tom' 'negotiate 10-15% discount'"
  echo "  $0 'Plombier Paris' '+33145551234' fr 'kitchen sink repair' 'Marie' 'get quote and availability'"
  exit 1
fi

BUSINESS="$1"
PHONE="$2"
LANGUAGE="$3"
SERVICE="$4"
CUSTOMER="$5"
GOAL="${6:-get quote and confirm timeline}"

# Build prompt
PROMPT="You are calling $BUSINESS to get a service quote for $CUSTOMER.

Service needed: $SERVICE
Goal: $GOAL

Instructions:
1. Introduce yourself as calling on behalf of $CUSTOMER
2. Explain the service needed: $SERVICE
3. Ask for a price quote
4. Ask about timeline/availability
5. ${GOAL}
6. Confirm final details (price, timeline, next steps)
7. Thank them and end

Be professional and direct. Get clear pricing and timeline."

# Make the call
bash "$SCRIPT_DIR/retell-call-task.sh" \
  "Quote from $BUSINESS" \
  "$PHONE" \
  "$LANGUAGE" \
  "$PROMPT" \
  "yes"
