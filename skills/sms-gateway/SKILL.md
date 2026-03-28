# SMS Gateway — Telnyx SMS/Voice Webhook for OpenClaw

**Two-way SMS gateway** that connects phone numbers to your OpenClaw agent. Inbound SMS → agent processes → auto-replies. Also auto-forwards verification codes to Telegram.

## What It Does

1. **Receive SMS** via Telnyx webhook
2. **Route to OpenClaw agent** for intelligent response
3. **Auto-reply** via SMS (chunked for long messages)
4. **Auto-forward verification codes** to Telegram (OTP, 2FA codes detected via regex)
5. **Signature verification** on all webhooks (Ed25519)

## Architecture

```
Inbound SMS (Telnyx)
    ↓
Webhook Server (port 8443)
    ↓
┌─ Verification code? ─→ Forward to Telegram instantly
│
└─ Regular message ─→ OpenClaw Gateway (/v1/chat/completions)
                          ↓
                     Agent processes
                          ↓
                     Reply via SMS (Telnyx API)
```

## Auto-Forward: Verification Codes

The killer feature. When an SMS contains a verification code (OTP, 2FA), it's **instantly forwarded to Telegram** — no agent processing needed.

**Detection regex:** `/verif|code|otp|one.time/i` AND `/\d{4,8}/`

This catches:
- "Your verification code is 123456"
- "Telegram code: 71505"
- "Your OTP: 4829"
- "One-time password: 382910"

**Telegram format:**
```
📲 SMS verification code received
From: 85474

Telegram code: 71505
```

## Setup Instructions

### Prerequisites
- Telnyx account with phone number
- OpenClaw gateway running
- Telegram bot token

### Step 1: Install Dependencies
```bash
mkdir ~/telnyx-sms-service
cd ~/telnyx-sms-service
npm init -y
npm install express telnyx dotenv
```

### Step 2: Configure Environment
```bash
cat > .env << 'EOF'
# Telnyx
TELNYX_API_KEY=your_telnyx_api_key
TELNYX_PUBLIC_KEY=your_ed25519_public_key
BOT_NUMBER=+1XXXXXXXXXX
WEBHOOK_PORT=8443

# OpenClaw
OPENCLAW_GATEWAY_URL=http://127.0.0.1:18789
OPENCLAW_GATEWAY_TOKEN=your_gateway_token
OPENCLAW_AGENT_ID=main

# Telegram (for code forwarding)
TELEGRAM_BOT_TOKEN=your_bot_token
EOF
```

### Step 3: Deploy Server
Copy `backend/server.js` to your service directory.

### Step 4: Set Up Telnyx Webhook
1. Go to Telnyx Mission Control → Messaging
2. Set webhook URL: `https://your-domain.com:8443/webhook`
3. Get public key from `/v2/public_key` for signature verification

### Step 5: Create systemd Service
```bash
cat > ~/.config/systemd/user/telnyx-sms.service << 'EOF'
[Unit]
Description=Telnyx SMS/Voice webhook for OpenClaw
After=network.target

[Service]
Type=simple
WorkingDirectory=/home/openclaw/telnyx-sms-service
ExecStart=/usr/bin/env node server.js
Restart=always
RestartSec=3

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now telnyx-sms
```

### Step 6: Verify
```bash
# Health check
curl http://127.0.0.1:8443/health

# Check logs
journalctl --user -u telnyx-sms -f
```

## Verification Code Forwarding

### How It Works
The server inspects every inbound SMS for verification code patterns:

```javascript
if (/verif|code|otp|one.time/i.test(text) && /\d{4,8}/.test(text)) {
  // Forward to Telegram immediately
}
```

### Customize Target
Change the Telegram chat_id in server.js:
```javascript
body: JSON.stringify({ chat_id: "YOUR_CHAT_ID", text: tgMsg, parse_mode: "Markdown" })
```

### Telegram Message Format
Codes are formatted with backticks for easy tap-to-copy:
```
📲 SMS verification code received
From: `85474`

`Your verification code is 123456`
```

## SMS Reply Behavior

- Messages are routed to OpenClaw agent via gateway
- Agent response is sent back as SMS
- `NO_REPLY` or `HEARTBEAT_OK` responses are silently dropped
- Long messages (>1500 chars) are automatically chunked

## Security

### Webhook Signature Verification
- Ed25519 signatures verified on every webhook
- Invalid signatures return 403 and are logged
- Set `TELNYX_PUBLIC_KEY` from Telnyx Mission Control

### Rate Limiting
- Telnyx handles rate limiting on their end
- No additional server-side rate limiting needed for inbound

### Secrets
All credentials in `.env`:
- `TELNYX_API_KEY` — API access
- `TELNYX_PUBLIC_KEY` — Webhook signature verification
- `OPENCLAW_GATEWAY_TOKEN` — Gateway auth
- `TELEGRAM_BOT_TOKEN` — Code forwarding

## Cost

- **Telnyx SMS:** ~$0.004/message inbound, ~$0.004/message outbound
- **Phone number:** ~$1/month
- **Typical usage:** $5-10/month

## Troubleshooting

### No SMS received
- Check Telnyx webhook URL is correct
- Verify port 8443 is accessible from internet
- Check `journalctl --user -u telnyx-sms -f`

### Signature verification failing
- Verify `TELNYX_PUBLIC_KEY` matches Telnyx Mission Control
- Check raw body middleware is before JSON parser for `/webhook` route

### Agent not responding
- Check OpenClaw gateway is running
- Verify `OPENCLAW_GATEWAY_TOKEN` is correct
- Check agent ID matches configured agent

### Verification codes not forwarding
- Check `TELEGRAM_BOT_TOKEN` is set
- Verify bot can send to the target chat_id
- Check SMS text matches the regex pattern

## Files Reference

```
skills/sms-gateway/
├── SKILL.md                    # This file
└── backend/
    └── server.js               # Express webhook server
```

---

**Built**: March 2026
**Status**: Production — running 4+ days uptime
**Cost**: ~$5-10/month
