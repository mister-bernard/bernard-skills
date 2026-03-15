# Retell Task Calls Skill

Make one-off phone calls for specific tasks using Retell AI's built-in LLM (fast, reliable, 31+ languages).

## When to Use

- Restaurant reservations
- Service quotes (mechanic, contractor, etc.)
- Appointment booking
- Customer support calls
- Negotiations
- Any task with a clear goal

## How It Works

1. You say: "Call this restaurant for a reservation" or "Call the mechanic for a quote"
2. I create a task-specific agent in Retell with a custom prompt
3. I make the call via API
4. I monitor the call and return transcript + result

## Quick Commands

- `/call-rez <restaurant> <date> <time> <people> [details]` - Make restaurant reservation
- `/call-quote <business> <service> [details]` - Get service quote
- `/call-task <number> <language> <task-description>` - General task call

## Environment

- **From number:** $RETELL_FROM_NUMBER (Retell-native)
- **Agent ID:** Created on-demand (task-specific)
- **Model:** Retell LLM (built-in, fast)
- **Cost:** ~$0.07-0.08/min (Retell) + international rates

## Configuration

**Required in Retell Dashboard:**
1. Default agent exists for templating
2. Phone number $RETELL_FROM_NUMBER assigned

**Required in `~/.openclaw/.env`:**
```bash
RETELL_API_KEY=key_42d0fff3dc9a5a3eb6e868269c75
```

## Examples

### Restaurant Reservation
```
Call Askaneli Falestra (+995 550 00 92 00) for dinner reservation:
- Date: Tomorrow 8pm
- Party: 4 people
- Preferences: Quiet table, Georgian wine list
```

**Result:** Agent created, call made, transcript returned with confirmation.

### Mechanic Quote
```
Call Georgian mechanic (+995...) for paint job quote:
- Customer: Tom
- Service: Full car paint job
- Goal: Get quote, negotiate 10-15% discount
```

**Result:** Agent speaks Georgian, gets quote, negotiates, confirms best price.

## Agent Creation Template

```json
{
  "llm_websocket_url": null,
  "general_prompt": "<task-specific-prompt>",
  "general_tools": [],
  "states": [],
  "agent_name": "<Task Name>",
  "language": "<language-code>",
  "voice_id": "<retell-voice-for-language>",
  "voice_temperature": 1.0,
  "responsiveness": 0.7,
  "interruption_sensitivity": 0.5,
  "ambient_sound": "off"
}
```

## Prompt Templates

### Restaurant Reservation
```
You are calling a restaurant to make a reservation.

Task:
- Restaurant: {name}
- Date/Time: {datetime}
- Party size: {people}
- Special requests: {details}

Instructions:
1. Greet politely in {language}
2. Request reservation for {people} on {datetime}
3. Mention any special requests
4. Confirm reservation details (time, party size, name)
5. Get confirmation number if available
6. Thank them and end call

Speak naturally and conversationally. Keep it brief.
```

### Service Quote
```
You are calling to get a service quote.

Task:
- Business: {name}
- Service needed: {service}
- Customer: {customer_name}
- Goal: {goal}

Instructions:
1. Introduce yourself and customer
2. Explain service needed
3. Ask for quote
4. {negotiation_strategy if applicable}
5. Confirm final price and timeline
6. Thank them and end

Be professional and direct. Get clear pricing.
```

## Post-Call Actions

After call completes:
1. Fetch call transcript via Retell API
2. Parse key details (confirmation, price, etc.)
3. Summarize result for user
4. Optionally: delete one-time agent to keep dashboard clean

## Notes

- ✅ Uses Retell's built-in LLM (fast, no custom backend needed)
- ✅ 31+ languages supported
- ✅ Auto voice selection per language
- ✅ Full transcript + recording available
- ⚠️ One-time agents can be deleted after call or kept for reuse
- ⚠️ No tool calling (for tools, use custom LLM backend)

## Script Locations

- `scripts/retell-call-rez.sh` - Restaurant reservations
- `scripts/retell-call-quote.sh` - Service quotes
- `scripts/retell-call-task.sh` - General task calls
- `scripts/retell-create-agent.sh` - Create task-specific agent
- `scripts/retell-get-transcript.sh` - Fetch call transcript
