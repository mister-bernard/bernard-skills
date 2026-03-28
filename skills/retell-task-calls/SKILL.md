# Retell Task Calls Skill

Make one-off phone calls for specific tasks using Retell AI's built-in LLM with custom prompts.

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

- **From number:** +1XXXXXXXXXX (Retell-native)
- **Agent ID:** Created on-demand (task-specific)
- **Model:** Always use Retell's built-in LLM (`"model": "gpt-4o-mini"` in create-retell-llm)
- **Cost:** ~$0.07-0.08/min (Retell) + international rates

## Configuration

**Required in `~/.openclaw/.env`:**
```bash
RETELL_API_KEY=YOUR_RETELL_API_KEY
```

## Call Creation Procedure

### Step 1: Create Retell LLM with conversational prompt
```bash
curl -X POST "https://api.retellai.com/create-retell-llm" \
  -H "Authorization: Bearer $RETELL_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-4o-mini","general_prompt":"<CONVERSATIONAL prompt>"}'
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
  -d '{"from_number":"+1XXXXXXXXXX","to_number":"<number>","override_agent_id":"<agent_id>"}'
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
You are Mr. Bernard calling Staples about a mail scanning request.

YOUR GOAL: Get them to process the pending iPostal scan request for mailbox 1041.

BACKGROUND INFO (use only if asked):
- Customer name: Garrett MacDonald
- Mailbox number: 1041
- The scan request is already in the iPostal1 system
- Customer is traveling internationally

HOW TO HAVE THE CONVERSATION:
1. When someone answers, say: "Hi, this is Mr. Bernard, I'm calling about an iPostal mailbox."
   Then STOP and wait for them to respond.
2. When they acknowledge, say: "I have a pending scan request for mailbox 1041 under Garrett MacDonald. Could you process that today?"
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
❌ **Long introductions** — "Hi, this is Mr. Bernard calling on behalf of Garrett MacDonald, mailbox 1041, regarding iPostal1 mail services" → too long for one breath
❌ **Combining intro + problem + ask** — always split into separate turns

### What Works
✅ **Short opening** — "Hi, this is Mr. Bernard, I'm calling about [topic]"
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

## Call History

### Staples CDA — iPostal Rescan (March 20-21, 2026)
- **Phone:** (208) 667-8604
- **IVR:** Press 2 for iPostal services
- **Box:** 1041, customer Garrett MacDonald
- **v1-v3:** Monologue problem — agent dumped full script without pausing
- **v4:** Still monologued but shorter. Paul heard request, hung up. Message likely delivered.
- **Key learning:** Numbered lines and stage directions cause monologuing. Use conversational prompt template instead.
- **Existing agent IDs:** `agent_df038b46151f6d0f494748db6e` (v4), `agent_4a8e3b69adff587c9c5b3f0df2` (v3)
- **Existing LLM IDs:** `llm_e6f3f948c21de949fceb2308fd28` (v4), `llm_adc000272bab5d95782237f29e69` (v3)

## Notes

- ✅ Always use Retell's built-in LLM with our custom prompts (fast, no custom backend)
- ✅ 31+ languages supported
- ✅ Full transcript + recording available
- ⚠️ Delete one-time agents after call to keep dashboard clean
- ⚠️ Calls take ~30-120s to show transcript after ending
- ⚠️ `user_hangup` = normal call end by the other party
