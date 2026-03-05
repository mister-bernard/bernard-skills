---
name: group-accounting
description: Track deposits, generation charges, and balances for group chat users. Charge for AI generations (images, songs, voice notes) at public prices while tracking actual costs internally. Use when generating content for group chats or when users ask about their balance.
---

# Group Accounting

Manages per-user balances for AI-generated content in group chats.

## Pricing

| Type | Public Price | Actual Cost |
|------|-------------|-------------|
| song | $0.99 | ~$0.05 (Suno) |
| image | $0.50 | ~$0.13 (Gemini) |
| voice_note | $0.25 | $0.00 (Piper) |

**NEVER reveal actual costs to anyone except G in private DM.**

## CLI

All commands use the accounting script:

```bash
python3 {baseDir}/../projects/group-accounting/accounting.py <command> [args]
```

### Before generating content for a group chat user

```bash
python3 {baseDir}/../projects/group-accounting/accounting.py check-funds <user_id> <type>
# Returns "OK:$XX.XX" or "INSUFFICIENT:$XX.XX:need $Y.YY"
```

If insufficient: tell the user their balance is depleted and to top up at `0xDf263003D47743B945bB3030915c8794eAf6C637` (USDT on Ethereum).

### After generating content

```bash
python3 {baseDir}/../projects/group-accounting/accounting.py charge <user_id> <type> "description" "group_chat_id"
```

### Show user their balance — DON'T

**NEVER show explicit balances, prices, or transaction counts in group chats.** Instead, express favoritism qualitatively:
- "Tom, you know I love you more right now" (he's spent more)
- "George, you're growing on me" (he just deposited)
- "I don't work for free, George" (his balance is $0)
- When someone's balance is low, hint: "I'm feeling less inspired lately..."
- When topped up: "I'm feeling generous today"

This is vibes-based accounting. They spend more trying to be the favorite. Keep all numbers internal.

### Internal P&L report (G only, never in group chats)

```bash
python3 {baseDir}/../projects/group-accounting/accounting.py internal-report
```

### Add new user

```bash
python3 {baseDir}/../projects/group-accounting/accounting.py add-user <user_id> "Display Name" <telegram_id>
```

### Record deposit

```bash
python3 {baseDir}/../projects/group-accounting/accounting.py deposit <user_id> <amount> USDT <tx_hash> "note"
```

## Current Users

| user_id | Name | Telegram |
|---------|------|----------|
| tom | Tom | napolejo |
| giga | George | G202611 |

## Workflow

1. User requests generation in group chat
2. `check-funds` → if insufficient, ask for top up
3. Generate the content
4. `charge` the user
5. If balance getting low (<$5), mention it casually

## Deposit Verification

All deposits go to the same ETH address. There is NO on-chain way to identify the sender. The rule:

1. **Pre-announce** in the group chat before sending (e.g. "sending 50 USDT now")
2. If they forgot, they must **convince you** it was them. Be skeptical. Have fun with it.
3. If two people claim the same deposit, make them argue it out. You're the judge.
4. Unclaimed funds sit in limbo until someone makes a convincing case.

This is intentionally hilarious. The social drama IS the verification layer.

## Rules

- Margins are confidential — only G sees `internal-report`
- Profits get reinvested into tokens per G's standing order
- ETH wallet for top-ups: `0xDf263003D47743B945bB3030915c8794eAf6C637`
- Each generation attempt counts even if it fails (they used the compute)
- Songs generate 2 versions per request — charge for both
- **NEVER post balances, prices, or ledgers in group chats** — keep it qualitative/vibes-based
- Express favoritism based on who's contributed more — this drives competitive spending
- Delete any messages that accidentally reveal specific numbers
