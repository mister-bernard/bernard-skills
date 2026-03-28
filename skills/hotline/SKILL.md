# Hotline — Voice Command Interface

**Push-to-talk voice hotline system** that transcribes audio and routes it to the agent for processing. Enables voice commands from anywhere with instant agent responses via Telegram.

## What It Does

1. **Record** — Press and hold to record voice message (PWA or iOS Shortcut)
2. **Transcribe** — Deepgram API converts audio to text (<1s latency, $0.0043/min)
3. **Route** — Message sent to agent via `openclaw agent --deliver`
4. **Respond** — Agent processes request and replies via Telegram
5. **GPS context** — Location automatically attached to every message

## Architecture

```
Voice Input (PWA/Shortcut)
    ↓
Backend API (/api/hotline)
    ↓
Deepgram Transcription (primary)
    ↓ (fallback)
OpenAI Whisper (if Deepgram fails)
    ↓
openclaw agent --deliver
    ↓
Agent receives as user message
    ↓
Response delivered to Telegram
```

## Components

### 1. Backend API
- **File**: `backend/hotline-handler.js` (integrate into Express server)
- **Endpoints**: 
  - `/api/hotline` (PWA)
  - `/voice` (iOS Shortcuts alias)
- **Features**:
  - Bearer token auth
  - GPS from headers (iOS) or FormData (PWA)
  - Multipart form-data AND raw binary POST support (iOS workaround)
  - Rate limiting (5s cooldown per key)
  - Async fire-and-forget agent delivery

### 2. PWA Frontend
- **Files**: `pwa/` directory (index.html, manifest.json, sw.js, icons)
- **Features**:
  - Hold-to-record button with waveform visualizer
  - GPS capture via Geolocation API
  - Offline-capable service worker
  - Dark theme
  - Haptic feedback

### 3. iOS Shortcut
- **File**: `shortcuts/hotline.shortcut` (import to Shortcuts app)
- **Features**:
  - Record audio
  - GPS via Location action
  - POST to `/voice` endpoint
  - **Critical**: Uses raw binary POST (not multipart) to avoid iOS Content-Type bug

## Setup Instructions

### Prerequisites
- OpenClaw gateway running
- Deepgram API key (free $100 trial: https://deepgram.com/)
- Telegram bot token (if not already configured)
- Domain with HTTPS (required for PWA Geolocation API)

### Step 1: Install Dependencies
```bash
cd ~/mrb-sh  # or your Express server directory
npm install formidable form-data
```

### Step 2: Configure Secrets
```bash
# Add to .env
echo "DEEPGRAM_API_KEY=your_key_here" >> .env
echo "HOTLINE_API_KEY=$(openssl rand -hex 32)" >> .env

# Save Deepgram key to vault
bash scripts/vault-get.sh --add "APIs/Deepgram" "your_key_here"
```

### Step 3: Integrate Backend
Copy `backend/hotline-handler.js` into your Express server:

```javascript
// In server.js, add:
const hotlineHandler = require('./hotline-handler.js');

// Register endpoints
app.post('/api/hotline', hotlineHandler);
app.post('/voice', hotlineHandler);
```

Update the agent delivery command with your:
- Agent ID (e.g., `opus-dm`)
- Reply channel (e.g., `telegram`)
- Target chat ID (e.g., `YOUR_TELEGRAM_CHAT_ID`)

### Step 4: Deploy PWA
```bash
# Copy PWA files to public directory
cp -r pwa/* ~/mrb-sh/public/hotline/

# Add to protected paths in server.js
protected_prefixes: ['/hotline']

# Add key to keys.json
{
  "YOUR_HOTLINE_API_KEY": {
    "label": "Hotline API",
    "paths": ["/hotline/*"]
  }
}
```

**Live URL**: `https://your-domain.com/hotline/?key=YOUR_KEY`

### Step 5: Install iOS Shortcut
1. Open `shortcuts/hotline.shortcut` on iPhone
2. Tap "Add Shortcut"
3. Edit the shortcut:
   - Replace `YOUR_DOMAIN` with your domain
   - Replace `YOUR_API_KEY` with your hotline API key
4. Add to Home Screen for quick access

### Step 6: Test
```bash
# Tail logs
journalctl --user -u mrb-sh -f | grep Hotline

# Send test via curl
curl -X POST https://your-domain.com/voice \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: audio/webm" \
  -H "X-Location-Lat: 37.7749" \
  -H "X-Location-Lon: -122.4194" \
  --data-binary @test-audio.webm
```

## iOS Shortcuts Content-Type Bug

**Problem**: iOS doesn't auto-set `multipart/form-data` header when Request Body = "File"

**Solution**: Backend accepts BOTH:
- Multipart form-data (PWA)
- Raw binary POST (iOS Shortcut)

Detection logic:
```javascript
const isMultipart = req.headers['content-type'].includes('multipart/form-data');
if (!isMultipart) {
  // Read raw request stream, save to file, process
}
```

## Cost Analysis

### Deepgram (primary)
- **Price**: $0.0043/minute
- **Free trial**: $100 = ~23,000 minutes (~385 hours)
- **Latency**: <1 second
- **Model**: nova-2 with smart_format

### OpenAI Whisper (fallback)
- **Price**: $0.006/minute
- **Latency**: 2-5 seconds
- **Model**: whisper-1

**Estimated monthly cost** (60 calls/day × 30s avg):
- 30 hours/month × $0.26/hour = **~$7.80/month**

## Security

### Authentication
- **Bearer token**: API key in Authorization header
- **Alternative**: `X-API-Key` header or `?key=` query param
- **Rate limit**: 5 seconds between calls per key

### Key Gating
- Entire `/hotline/` path protected
- No public access without key
- Setup docs removed from public access

### Environment Variables
```bash
DEEPGRAM_API_KEY=your_deepgram_key_here
HOTLINE_API_KEY=your_hotline_key_here
TELEGRAM_BOT_TOKEN=your_telegram_bot_token_here
OPENCLAW_GATEWAY_URL=http://127.0.0.1:18789  # optional, defaults to localhost
```

## Maintenance

### Monitor Deepgram Credits
```bash
# Check remaining balance
curl -H "Authorization: Token $DEEPGRAM_API_KEY" \
  https://api.deepgram.com/v1/projects
```

When credits depleted:
1. Create new Deepgram account
2. Get new $100 trial key
3. Update `.env` and vault
4. Restart server

### Logs
```bash
# Watch hotline activity
journalctl --user -u mrb-sh -f | grep -E "Hotline|Agent"

# Check transcription errors
journalctl --user -u mrb-sh --since today | grep "Deepgram API error"
```

## Troubleshooting

### "Invalid form data" error
- iOS Shortcut: Check that Content-Type is NOT manually set
- Backend should see `audio/x-m4a` or `audio/webm` (not multipart)

### "Agent error: /bin/sh: openclaw: not found"
- Use full path: `/home/openclaw/.npm-global/bin/openclaw`
- Set PATH in exec env: `/home/openclaw/.npm-global/bin:/usr/local/bin:/usr/bin:/bin`

### Timeout after 30 seconds
- Use `exec()` not `execSync()` for async fire-and-forget
- Don't wait for agent response in hotline handler

### No Telegram response
- Check agent ID is correct (`openclaw agents list`)
- Verify Telegram bot token in env
- Check gateway is running (`ps aux | grep openclaw-gateway`)

### GPS not captured
- PWA: Requires HTTPS (localhost exception for dev)
- iOS: Check Location permission for Shortcuts app
- Backend: GPS in `X-Location-Lat`/`X-Location-Lon` headers (iOS) or FormData `location` field (PWA)

## Files Reference

```
skills/hotline/
├── SKILL.md                      # This file
├── backend/
│   └── hotline-handler.js        # Express middleware
├── pwa/
│   ├── index.html                # Main PWA interface
│   ├── manifest.json             # PWA manifest
│   ├── sw.js                     # Service worker
│   ├── icon-192.png              # App icon
│   └── icon-512.png              # App icon (large)
└── shortcuts/
    └── hotline.shortcut          # iOS Shortcut (export)
```

## Usage Examples

### Voice Commands
- "What's the weather in Seattle?"
- "Add milk to shopping list"
- "Summarize my inbox"
- "Find vegan restaurants near me"
- "Remind me to call mom at 3pm"

### GPS Context
Every message includes location:
```
[Location: 22.287976, 114.151301 - https://maps.google.com/maps?q=22.287976,114.151301]
```

Agent can use this for:
- Location-based search (restaurants, services, etc.)
- Travel status updates
- Emergency coordination

## Deployment Checklist

- [ ] Deepgram API key in vault + .env
- [ ] Hotline API key generated
- [ ] Backend integrated into Express server
- [ ] PWA deployed to `/hotline/` with key protection
- [ ] iOS Shortcut configured and tested
- [ ] Agent ID updated in backend code
- [ ] Telegram delivery target verified
- [ ] Test end-to-end: record → transcribe → agent → response
- [ ] Monitor Deepgram credit usage

## Future Enhancements

- [ ] Multi-user support (route by API key)
- [ ] Voice response (TTS reply via Telegram voice message)
- [ ] Conversation history UI
- [ ] Wake word detection (always-listening mode)
- [ ] Noise cancellation preprocessing
- [ ] Custom voice commands (shortcuts/macros)
- [ ] Analytics dashboard (usage, transcription accuracy, response times)

---

**Built**: March 27, 2026  
**Status**: Production-ready  
**Cost**: ~$7.80/month for typical usage
