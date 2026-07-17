# Retell Task Calls Skill

Make one-off phone calls for specific tasks using Retell AI's built-in LLM with custom prompts.

> **2026-07-17 revival notes:** Retell is WORKING again. The 2026-06 "media never bridges"
> outage was deprecated usage: `gpt-4o-mini` is no longer a valid Retell model and old
> engine-less agents are dead. Canonical, battle-tested caller (voicemail-after-beep via
> `voicemail_option`, fast re-delivery, live-tested on real reservation calls):
> the local `retell-calls` project (retell-call.sh + reservation prompt templates).
> Use the Retell-managed (Twilio-type) number for outbound — confirm what's provisioned
> with `GET /list-phone-numbers`; imported SIP-trunk numbers may not bridge inbound.

## When to Use

- Restaurant reservations
- Service quotes (mechanic, contractor, etc.)
- Appointment booking
- Customer support calls
- Negotiations
- Any task with a clear goal

## How It Works

1. You say: "Call this restaurant for a reservation" or "Call the mechanic for a quote"
2. I create a Retell LLM with a conversational prompt
3. I create a temp agent using that LLM
4. I make the call via API
5. I monitor the call and return transcript + result

## Quick Commands

- `/call-rez <restaurant> <date> <time> <people> [details]` - Make restaurant reservation
- `/call-quote <business> <service> [details]` - Get service quote
- `/call-task <number> <language> <task-description>` - General task call

## Environment

- **From number:** Set via `RETELL_FROM_NUMBER` env var (Retell-native)
- **Operator name:** Set via `OPERATOR_NAME` env var (used in agent self-introduction)
- **Agent ID:** Created on-demand (task-specific)
- **Model:** Always use Retell's built-in LLM (`"model": "claude-4.5-haiku"` in create-retell-llm — `gpt-4o-mini` was REMOVED from Retell's model list 2026; using it yields a silently-dead agent)
- **Cost:** ~$0.07-0.08/min (Retell) + international rates

## Configuration

**Required in `~/.openclaw/.env` (or `$OPENCLAW_ENV_FILE`):**
```bash
RETELL_API_KEY=YOUR_RETELL_API_KEY
RETELL_FROM_NUMBER=+1XXXXXXXXXX    # your Retell-managed number (check GET /list-phone-numbers)
OPERATOR_NAME=Your Name        # appears in agent's self-intro
```

## Call Creation Procedure

### Step 1: Create Retell LLM with conversational prompt
```bash
curl -X POST "https://api.retellai.com/create-retell-llm" \
  -H "Authorization: Bearer $RETELL_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"claude-4.5-haiku","general_prompt":"<CONVERSATIONAL prompt>","start_speaker":"user"}'
```

### Step 2: Create temp agent
```bash
curl -X POST "https://api.retellai.com/create-agent" \
  -H "Authorization: Bearer $RETELL_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"agent_name":"Task - <desc>","voice_id":"11labs-Brian","response_engine":{"type":"retell-llm","llm_id":"<llm_id>"},"responsiveness":0.6,"interruption_sensitivity":0.5}'
```
Note: `ambient_sound` must be one of: coffee-shop, convention-hall, summer-outdoor, mountain-outdoor, static-noise, call-center. Omit if not needed.

### Step 3: Make the call
```bash
curl -X POST "https://api.retellai.com/v2/create-phone-call" \
  -H "Authorization: Bearer $RETELL_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"from_number\":\"$RETELL_FROM_NUMBER\",\"to_number\":\"<number>\",\"override_agent_id\":\"<agent_id>\"}"
```

### Step 4: Check status (wait ~2-3 min)
```bash
curl "https://api.retellai.com/v2/get-call/<call_id>" \
  -H "Authorization: Bearer $RETELL_API_KEY"
```

### Step 5: Clean up (optional)
Delete temp agent + LLM after call.

## Prompt Design Rules (NON-NEGOTIABLE)

### The #1 Rule: Be Conversational, Not Scripted
The agent must speak like a real human on the phone. **ONE thought per turn, then WAIT for a response.** Never dump multiple sentences at once.

### Anti-Monologue Rules
1. **Each turn = ONE short sentence or question.** Never combine intro + problem + request into one block.
2. **After every sentence, STOP and wait for the other person to respond.** Do not continue until they speak.
3. **Never use stage directions in the prompt** like `[Brief pause]` or `[Wait for response]` — the LLM will read them aloud or include them literally.
4. **Model the conversation as a natural back-and-forth dialogue**, not a script to read.

### Anti-Apology Rules
- Never say "did you hear me?" or "are you still there?" or "I apologize"
- If there's silence, just wait. Don't fill it.

### IVR Navigation
- Stay silent during automated greetings — don't talk over them
- When the menu finishes, say the number clearly
- Include IVR instructions in prompt: "When you hear the automated menu, wait for it to finish, then say '2'"

### Prompt Structure Template
```
You are [name] calling [business] about [topic].

YOUR GOAL: [one clear sentence about what you need]

BACKGROUND INFO (use only if asked):
- [detail 1]
- [detail 2]

HOW TO HAVE THE CONVERSATION:
1. When someone answers, say: "Hi, this is [name], I'm calling about [topic]."
   Then STOP and wait for them to respond.
2. When they acknowledge you, explain what you need in ONE sentence.
   Then STOP and wait.
3. Answer any questions they have naturally.
4. When they confirm they'll help, thank them and say goodbye.

IMPORTANT:
- Speak ONE sentence at a time, then wait for a response.
- Do NOT give your full explanation all at once.
- Be warm and professional, like a normal phone call.
- If they ask for details, provide them. Don't volunteer everything upfront.
- If transferred, start over with step 1 when someone new answers.
- If you reach voicemail, leave a brief message with your name, the topic, and a callback number.
```

### Example: iPostal Scan Request (What Works)
```
You are <OPERATOR_NAME> calling <STORE_NAME> about a mail scanning request.

YOUR GOAL: Get them to process the pending iPostal scan request for mailbox <BOX_NUMBER>.

BACKGROUND INFO (use only if asked):
- Customer name: <CUSTOMER_NAME>
- Mailbox number: <BOX_NUMBER>
- The scan request is already in the iPostal1 system
- Customer is traveling internationally

HOW TO HAVE THE CONVERSATION:
1. When someone answers, say: "Hi, this is <OPERATOR_NAME>, I'm calling about an iPostal mailbox."
   Then STOP and wait for them to respond.
2. When they acknowledge, say: "I have a pending scan request for mailbox <BOX_NUMBER> under <CUSTOMER_NAME>. Could you process that today?"
   Then STOP and wait.
3. If they need more info, tell them the request is already in the iPostal system.
4. If they confirm, say: "Great, thank you so much. Have a good day."

When you hear the automated menu, wait for it to finish, then say "2" for iPostal services.

IMPORTANT:
- ONE sentence at a time, then wait.
- Do NOT explain everything in one breath.
- Be warm and brief, like a normal phone call.
```

### What NOT to Do (Learned the Hard Way)
❌ **Multi-paragraph scripts** — agent reads them as one continuous monologue
❌ **Stage directions in brackets** — `[Brief pause]` gets spoken or included literally
❌ **Numbered "Line 1, Line 2, Line 3"** — agent treats it as a sequential script to dump
❌ **"Say ONLY what is written below"** — makes agent robotic, not conversational
❌ **Long introductions** — "Hi, this is <OPERATOR> calling on behalf of <CUSTOMER>, mailbox <BOX>, regarding iPostal1 mail services" → too long for one breath
❌ **Combining intro + problem + ask** — always split into separate turns

### What Works
✅ **Short opening** — "Hi, this is <OPERATOR>, I'm calling about [topic]"
✅ **Wait instructions** — "Then STOP and wait for them to respond"
✅ **Background info section** — details available IF asked, not volunteered upfront
✅ **Natural dialogue flow** — model it as a conversation, not a presentation
✅ **One goal stated clearly** — agent knows what success looks like

## Voice Selection

- **English (default):** `11labs-Brian` — professional male voice
- **Other languages:** Use Retell's auto voice selection per language code
- Set `responsiveness: 0.6` (slightly lower = less likely to cut in)
- Set `interruption_sensitivity: 0.5`

## Post-Call Actions

After call completes:
1. Fetch call transcript via Retell API
2. Parse key details (confirmation, price, etc.)
3. Summarize result for user
4. Optionally: delete one-time agent to keep dashboard clean

## Lessons learned

- **Monologuing is the #1 failure mode.** Numbered lines and stage
  directions in the prompt cause the agent to dump the entire script in
  one breath. Use the conversational template (one short turn at a
  time, explicit STOP-and-wait instructions).
- **Voicemail vs live answer:** the agent doesn't reliably distinguish
  the two. Include a short voicemail fallback at the end of the prompt.
- **IVR menus:** keep silent during the greeting, then clearly say the
  menu choice. Worth scripting explicitly.

## Notes

- ✅ Always use Retell's built-in LLM with our custom prompts (fast, no custom backend)
- ✅ 31+ languages supported
- ✅ Full transcript + recording available
- ⚠️ Delete one-time agents after call to keep dashboard clean
- ⚠️ Calls take ~30-120s to show transcript after ending
- ⚠️ `user_hangup` = normal call end by the other party
