#!/usr/bin/env bash
# Quick restaurant reservation call

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ $# -lt 5 ]; then
  echo "Usage: $0 <restaurant_name> <phone> <language> <date_time> <party_size> [special_requests]"
  echo ""
  echo "Examples:"
  echo "  $0 'Askaneli Falestra' '+995550009200' ka-GE 'tomorrow 8pm' 4 'quiet table'"
  echo "  $0 'Le Jules Verne' '+33145556144' fr 'March 10 7:30pm' 2 'window seat'"
  exit 1
fi

RESTAURANT="$1"
PHONE="$2"
LANGUAGE="$3"
DATETIME="$4"
PARTY_SIZE="$5"
SPECIAL="${6:-none}"

# Build prompt
PROMPT="You are calling $RESTAURANT to make a dinner reservation.

Task:
- Date/Time: $DATETIME
- Party size: $PARTY_SIZE people
- Special requests: $SPECIAL

Instructions:
1. Greet politely and ask to make a reservation
2. Provide date, time, and party size
3. Mention special requests if any
4. Confirm all details (date, time, party size, name)
5. Get confirmation number if they provide one
6. Thank them and end the call

Speak naturally. Keep it brief and friendly."

# Make the call
bash "$SCRIPT_DIR/retell-call-task.sh" \
  "Reservation at $RESTAURANT" \
  "$PHONE" \
  "$LANGUAGE" \
  "$PROMPT" \
  "yes"
