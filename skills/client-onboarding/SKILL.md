# Client Onboarding Skill

Standardized workflow for onboarding new clients to managed OpenClaw instances using our Bootstrap framework.

## Overview

We provision and manage OpenClaw VPS instances for clients. Each client gets:
- Their own Hetzner VPS running OpenClaw + our Bootstrap kit
- A Telegram bot connected to their instance
- A usage dashboard at `<YOUR_DOMAIN>/client/<name>/`
- Isolated environment variables (prefixed `<CLIENT>_`)
- A client record in our workspace for tracking

## Directory Structure

```
# Our workspace (VPS)
~/.openclaw/workspace/
  clients/
    <name>.md              ← Client profile + setup status
    <name>.env             ← Client's isolated env vars (NOT in main .env)
  
# <YOUR_DOMAIN> website
~/mrb-sh/
  data/clients/
    <name>.json            ← Billing, usage, payments data
  public/client/
    <name>/
      index.html           ← Usage dashboard
      <project>/           ← Additional project pages

# Client's VPS
/home/openclaw/            ← Standard OpenClaw install with Bootstrap
```

## Onboarding Checklist

### Phase 1: Infrastructure (15 min)

1. **Provision VPS**
   ```bash
   # Hetzner Cloud — CX22 default ($4.15/mo: 2 vCPU/4GB/40GB)
   # Upgrade to CX32 ($7.45/mo: 4 vCPU/8GB/80GB) only if heavy tool use
   # Location: Hillsboro (US West) or Ashburn (US East), closest to client
   bash skills/client-onboarding/scripts/provision.sh <client_name>
   ```

2. **Run Bootstrap**
   ```bash
   # SSH into new VPS, install OpenClaw + Bootstrap
   ssh root@<ip> 'bash -s' < ~/bernard-bootstrap/provision/provision-vps.sh
   ```

3. **Configure Telegram Bot**
   - Client creates bot via @BotFather
   - Get bot token from client
   - Save as `<CLIENT>_TELEGRAM_BOT_TOKEN` in client env file

4. **Configure Anthropic API**
   - Option A: Client provides their own API key → save as `<CLIENT>_ANTHROPIC_API_KEY`
   - Option B: We share our subscription → deploy via `deploy-shared-keys.sh`, track usage, bill at cost (1x)
   - **Recommend clients use subscription ($20/mo) over API keys** — dramatically cheaper for typical usage
   - Configure on their VPS: `~/.openclaw/.env`

5. **Start Gateway**
   ```bash
   ssh openclaw@<ip> 'openclaw gateway start'
   ```

### Phase 2: Client Record (5 min)

1. **Create client profile**: `clients/<name>.md` (use template below)
2. **Create client env file**: `clients/<name>.env`
3. **Create billing record**: `~/mrb-sh/data/clients/<name>.json`
4. **Add to client registry**: `clients/registry.json`

### Phase 3: Dashboard (5 min)

1. **Create client web directory**: `~/mrb-sh/public/client/<name>/`
2. **Deploy dashboard**: Copy template, customize with client name
3. **Verify**: `https://<YOUR_DOMAIN>/client/<name>/?key=<API_KEY>`

### Phase 4: Identity (10 min)

1. SSH into client VPS
2. Help client customize: SOUL.md, IDENTITY.md, USER.md
3. Set timezone in `config/timezone.txt`
4. Verify bot responds in Telegram

## Environment Variable Convention

**All client keys are stored in `clients/<name>.env`** — NEVER in our main `~/.openclaw/.env`.

Naming: `<CLIENT_UPPER>_<KEY_NAME>`

```bash
# clients/<CLIENT_NAME>.env
YONI_TELEGRAM_BOT_TOKEN=8534473657:AAG...
YONI_TELEGRAM_BOT_TOKEN_ALT=8680094855:AAE...
YONI_ANTHROPIC_API_KEY=sk-ant-api03-Lsf...
YONI_VPS_IP=$CLIENT_VPS_IP
YONI_HETZNER_SERVER_ID=$CLIENT_HETZNER_ID
YONI_SSH_KEY_PATH=~/.ssh/client-<CLIENT_NAME>
```

**To use a client's env vars:**
```bash
# Load a specific client's env (isolated from ours)
source clients/<name>.env

# Or read a specific key
grep YONI_VPS_IP clients/<CLIENT_NAME>.env | cut -d= -f2
```

**Rules:**
- Client env files are gitignored (contain secrets)
- Client .md profiles are version-controlled (no secrets in .md)
- Never mix client keys into `~/.openclaw/.env`
- The .md profile references env var NAMES, never values

## Client Profile Template

```markdown
# Client: <Full Name>

- **Telegram:** @<handle> (ID: <id>)
- **Status:** Active | Setup | Paused | Churned
- **Start date:** YYYY-MM-DD
- **Referred by:** <source>

## Infrastructure
- **VPS:** Hetzner `<server-name>` (ID: <hetzner_id>)
- **IP:** <ip_address>
- **Spec:** CX22 — 2 vCPU / 4GB RAM / 40GB SSD (<location>)
- **Cost:** ~$4.15/mo
- **OS:** Ubuntu 24.04
- **OpenClaw:** Installed, gateway <running|stopped>
- **Bot:** @<bot_username> (ID: <bot_id>)
- **Agent name:** <agent_persona_name>
- **Model:** <primary_model>

## Environment Variables (<PREFIX>_ prefix)
- `<PREFIX>_TELEGRAM_BOT_TOKEN` — <bot_id>:<partial>... (@<bot_username>)
- `<PREFIX>_ANTHROPIC_API_KEY` — sk-ant-... (stored in clients/<name>.env)
- `<PREFIX>_VPS_IP` — <ip>
- `<PREFIX>_HETZNER_SERVER_ID` — <id>

## Setup Status
- [ ] VPS provisioned
- [ ] OpenClaw installed
- [ ] Bootstrap templates deployed
- [ ] Systemd service configured
- [ ] Firewall (UFW) enabled
- [ ] Anthropic API key configured
- [ ] Telegram bot connected
- [ ] Gateway running
- [ ] Agent identity customized
- [ ] Usage dashboard deployed
- [ ] First heartbeat confirmed
- [ ] Client walkthrough completed

## Billing
- **Payment method:** <ETH | stablecoins | invoice>
- **ETH address:** 0xDf263003D47743B945bB3030915c8794eAf6C637
- **Monthly costs:**
  - VPS: ~$<amount>/mo
  - Anthropic API: variable (tracked)
  - Total estimate: $<range>/mo

## Usage Tracking
- Dashboard: <YOUR_DOMAIN>/client/<name>/?key=<MRB_API_KEY>

## Notes
<free-form notes about this client>
```

## Client Registry

Maintained at `clients/registry.json`:

```json
{
  "clients": [
    {
      "id": "<CLIENT_NAME>",
      "name": "<CLIENT_FULLNAME>",
      "status": "active",
      "vps_ip": "YONI_VPS_IP",
      "telegram": "@<CLIENT_NAME>9091",
      "start_date": "2026-02-27",
      "monthly_vps": 13.00,
      "env_file": "clients/<CLIENT_NAME>.env",
      "profile": "clients/<CLIENT_NAME>.md",
      "dashboard": "<YOUR_DOMAIN>/client/<CLIENT_NAME>/"
    }
  ]
}
```

## Website Structure

```
<YOUR_DOMAIN>/client/                    ← Client portal index (lists all clients, auth required)
<YOUR_DOMAIN>/client/<name>/             ← Client usage dashboard
<YOUR_DOMAIN>/client/<name>/status       ← System health check (API)
<YOUR_DOMAIN>/client/<name>/<project>/   ← Project-specific pages
```

All `/client/` routes require `?key=<MRB_API_KEY>` — returns 404 without it.

## Health Monitoring

Check client VPS health:
```bash
bash skills/client-onboarding/scripts/health-check.sh <client_name>
# Checks: SSH reachable, gateway running, bot responsive, disk/memory
```

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/provision.sh <name>` | Create client env file, profile, billing JSON, web directory |
| `scripts/health-check.sh <name>` | SSH health check (gateway, disk, services) |
| `scripts/usage-sync.sh <name>` | Pull Anthropic usage data from client VPS |
| `scripts/deploy-dashboard.sh <name>` | Deploy/update client dashboard page |

## Billing & Pricing

### Multipliers (Universal)
| Category | Multiplier | Example |
|----------|-----------|---------|
| VPS hosting | **5x** | $13 actual → $65 billed |
| Anthropic API | **1x** (at cost) | Pass-through, no markup |
| All other APIs | **5x** | Gemini, ElevenLabs, etc. |

Multipliers are defined in `~/mrb-sh/routes/client-usage.js` → `MULTIPLIERS` constant.

### Payments (Crypto → USD)
- Clients send ETH, USDC, USDT, or any token to `0xDf263003D47743B945bB3030915c8794eAf6C637`
- **When payment arrives**, record in `data/clients/<name>.json` → `payments[]`:
  ```json
  {
    "date": "2026-02-27",
    "crypto": "ETH",
    "amount_crypto": 0.2196,
    "price_at_payment": 1922.24,
    "usd_value": 422.12,
    "tx_hash": "0x...",
    "converted_to": "USDC",
    "note": "First month"
  }
  ```
- **Convert non-stablecoins to USDC/USDT immediately** (via Kraken or DEX). Keep as operating reserves.
- USD value locked at conversion time — no retroactive price adjustments.

### Balance Tracking
- `balance = total_paid_usd - total_billed`
- Dashboard shows real-time balance with color coding:
  - 🟢 Green: balance ≥ $50
  - 🟡 Yellow: $0 ≤ balance < $50
  - 🔴 Red: balance < $0 (owes money)
- **Auto-alert**: When balance drops below $50, notify client to top up.

### Usage Sync
1. `usage-sync.sh` SSHes into client VPS, reads OpenClaw session JSONL files
2. Aggregates tokens per day, estimates cost (Sonnet: $3/M in, $15/M out)
3. Stores in `data/clients/<name>.json` → `apiUsage[]`
4. Dashboard at `<YOUR_DOMAIN>/client/<name>/` renders everything in USD

### Dashboards
- **Client URL**: `<YOUR_DOMAIN>/client/<name>/?key=<CLIENT_DASHBOARD_KEY>` (unique per client)
- **Admin URL**: `<YOUR_DOMAIN>/client/<name>/?key=<MRB_API_KEY>` (admin key accesses all)
- **Revenue API**: `GET /api/clients/revenue?key=<MRB_API_KEY>` (admin — aggregated P&L)
- Shows: balance, total paid (USD), total billed, monthly rate, services breakdown, payment history, API usage
- Each client gets a unique dashboard key generated during provisioning (stored in `data/clients/keys.json`)
- Clients see their own dashboard only; admin key sees all
- Auto-refreshes every 60s

### Aave Yield on Idle Stables
- Script: `/home/openclaw/eth-wallet/aave-deposit.js`
- Usage: `node aave-deposit.js <USDT|USDC> <amount> [--confirm]`
- Deposits idle stablecoins into Aave V3 on Ethereum mainnet
- Client payments converted to USDC/USDT → deposited into Aave when not needed for expenses
- Current rates: USDT ~1.9%, USDC ~2.0% APY

## Payment Lifecycle (Critical Workflow)

### When a Client Sends Payment
1. Client tells you they sent crypto (or gives you a tx hash)
2. **Verify on-chain**: `node ~/eth-wallet/ -e "..."` or etherscan to confirm amount, sender, token
3. **Record it**: `bash skills/client-onboarding/scripts/record-payment.sh <client> <crypto> <amount> <tx_hash> --note "..."`
4. **Convert non-stablecoins**: Swap ETH/BTC/etc to USDC or USDT immediately (Kraken or on-chain)
5. **Update billing JSON**: Script does this automatically, but verify `converted_to` field after swap
6. **Deposit idle stables to Aave**: If total idle stablecoins > $1,000, deposit via `aave-deposit.js`
7. **Confirm to client**: Tell them their balance and runway

### Low Balance Alerts
- Run `bash skills/client-onboarding/scripts/check-balances.sh` during heartbeats or cron
- When balance < $50: message the client via their Telegram group with:
  ```
  Hey [name] — your Mr. Bernard account balance is getting low ($XX.XX remaining, ~X.X months).
  
  To top up, send ETH, USDC, or USDT to:
  0xDf263003D47743B945bB3030915c8794eAf6C637
  
  Just let me know when you've sent it and I'll credit your account.
  ```
- When balance < $0: escalate to G

### When a Client Says "I Sent Payment"
1. Ask: "Got it — what's the transaction hash or the amount/token you sent?"
2. Look up the tx on-chain to verify exact amount
3. Run `record-payment.sh` with verified data
4. Respond: "Credited! Your balance is now $X.XX (~X months of runway)."
5. **Never trust claimed amounts** — always verify on-chain

### Scripts Reference
| Script | Purpose |
|--------|---------|
| `scripts/record-payment.sh <client> <crypto> <amount> <tx_hash>` | Record + price a payment |
| `scripts/check-balances.sh [--alert]` | Report all client balances, flag low accounts |
| `scripts/provision.sh <name>` | Create client (auto-generates dashboard key) |
| `scripts/health-check.sh <name>` | SSH health check (gateway, disk, services) |
| `scripts/usage-sync.sh <name>` | Pull token usage from client VPS |
| `scripts/deploy-dashboard.sh <name>` | Deploy/update client dashboard page |
| `scripts/deploy-shared-keys.sh <name>` | Push our Anthropic auth to client VPS |

### Data Files (Deterministic Paths)
```
~/mrb-sh/data/clients/<name>.json     ← Billing, payments, usage (source of truth)
~/mrb-sh/data/clients/keys.json       ← Per-client dashboard API keys
~/.openclaw/workspace/clients/<name>.md    ← Client profile (infra, setup status)
~/.openclaw/workspace/clients/<name>.env   ← Client secrets (gitignored)
~/.openclaw/workspace/clients/registry.json ← Client index
```

All payment data lives in `~/mrb-sh/data/clients/<name>.json` → `payments[]` array.
All balance calculations derive from this file via `~/mrb-sh/routes/client-usage.js`.
Revenue aggregation: `GET /api/clients/revenue?key=<MRB_API_KEY>`.

## Offboarding

1. Export client data (workspace backup via tar)
2. Transfer DNS/bot ownership if needed
3. Delete VPS (Hetzner API or console)
4. Remove client env file
5. Update registry.json status → "churned"
6. Archive client profile (don't delete — billing records)

## Troubleshooting

### Gateway Not Responding After VPS Reboot

**Symptom:** Client reports bot not responding. `openclaw status` shows gateway service as "unknown" or unable to connect to systemd.

**Root cause:** Systemd user services require `loginctl enable-linger` to persist after logout/reboot. Without linger, user services only run while the user is logged in.

**Fix:**
```bash
# On the client VPS (as root):
ssh root@<client_vps_ip>
loginctl enable-linger openclaw

# Then start the gateway (as openclaw user):
ssh openclaw@<client_vps_ip>
export PATH=$HOME/.npm-global/bin:$PATH
openclaw gateway start
```

**Prevention:** The provision script (`bernard-bootstrap/provision/provision-vps.sh`) now includes the linger step automatically. All VPS provisioned after 2026-02-28 will have this configured from the start.

**Verification:**
```bash
# Check if linger is enabled:
ssh root@<client_vps_ip> "loginctl show-user openclaw | grep Linger"
# Should output: Linger=yes
```

This issue was discovered 2026-02-28 when <CLIENT>'s gateway wasn't auto-starting. Both <CLIENT_A> and <CLIENT_B>'s VPS have been fixed and the provision script updated.
