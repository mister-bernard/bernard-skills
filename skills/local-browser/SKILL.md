# Local Browser (Stealth VNC + Playwright)

## What This Is
A headed Chromium browser running inside a virtual display (Xvfb) on the VPS. Passes Cloudflare challenges, persists login sessions, and can be controlled both interactively (VNC) and programmatically (Playwright).

**Key insight:** Headed Chromium in Xvfb + stealth plugin looks identical to a real user to bot detection. Headless gets blocked; this doesn't.

## Architecture
```
[Xvfb :99]  →  Virtual 1280×800 display (no physical monitor)
[fluxbox]   →  Minimal window manager (2MB RAM)
[x11vnc]    →  VNC server, localhost:5900 only (SSH tunnel required)
[Chromium]  →  Real browser with persistent cookie profiles
[Playwright-extra + stealth]  →  Programmatic control that evades bot detection
```
**Total RAM:** ~50MB (without browser), ~350MB (with one Chromium instance)

## Setup
All runs as `monitor` user on the VPS.

- **Service:** `monitor-vnc.service` (systemd, auto-starts on boot)
- **Profiles:** `/home/monitor/.profile-account1/`, `.profile-account2/`
- **Scripts:** `/home/monitor/scripts/`
- **Playwright browsers:** Shared from `/home/openclaw/.cache/ms-playwright/`
- **VNC password:** In env as `MONITOR_VNC_PASSWORD`

## Interactive Use (VNC)
For initial logins, CAPTCHAs, or anything needing human interaction:
```bash
# From your local machine
ssh -L 5900:localhost:5900 monitor@<VPS_IP>
# Then open VNC viewer → localhost:5900

# On the VPS (as monitor user)
/home/monitor/open-browser.sh 1   # Opens Chromium with profile 1
/home/monitor/open-browser.sh 2   # Profile 2 (side by side)
```
The script stays open with a `URL>` prompt — paste magic links / auth URLs to open them in the browser.

## Programmatic Use (Playwright)
For automated scraping, monitoring, form filling:
```javascript
const { chromium } = require('playwright-extra');
const stealth = require('puppeteer-extra-plugin-stealth')();
chromium.use(stealth);

const CHROME = '/home/openclaw/.cache/ms-playwright/chromium-1208/chrome-linux64/chrome';

const browser = await chromium.launchPersistentContext('/home/monitor/.profile-accountN', {
  headless: false,        // MUST be false — runs in Xvfb, looks real to CF
  executablePath: CHROME,
  args: ['--no-sandbox', '--disable-dev-shm-usage', '--disable-blink-features=AutomationControlled'],
  viewport: { width: 1280, height: 800 },
});

const page = browser.pages()[0] || await browser.newPage();
await page.goto('https://example.com', { waitUntil: 'domcontentloaded' });
// waitUntil: 'domcontentloaded' NOT 'networkidle' — streaming sites hang on networkidle
```

**IMPORTANT:** Must set `DISPLAY=:99` when running from cron or scripts:
```bash
DISPLAY=:99 node /home/monitor/scripts/my-scraper.js
```

## Cloudflare Bypass
- **headless: true** → gets Cloudflare challenge page, BLOCKED
- **headless: false + Xvfb** → passes challenge automatically (~5-10s)
- **stealth plugin** → removes automation fingerprints (webdriver flag, etc.)
- Wait loop pattern for CF challenge resolution:
```javascript
for (let i = 0; i < 15; i++) {
  await page.waitForTimeout(1000);
  const text = await page.evaluate(() => document.body.innerText);
  if (!text.includes('security verification')) break;
}
```

## Use Cases
1. **Claude.ai usage monitoring** — scrape settings/usage page with persistent login
2. **CAPTCHA-protected sites** — solve interactively via VNC, then automate
3. **Authenticated scraping** — log in once via VNC, cookies persist for automated runs
4. **Form submission** — fill and submit forms on sites that block headless browsers
5. **Screenshot/PDF generation** — for sites that detect and block headless
6. **Browser-based auth flows** — OAuth, magic links, 2FA with persistent sessions

## Gotchas
- **Profile lock:** Can't run Playwright on a profile that has an open Chrome instance. Kill Chrome first: `pkill -f "chrome.*profile-accountN"`
- **Cookie expiry:** Sessions expire (varies by site). Re-login via VNC when scraper reports "Not logged in"
- **waitUntil: 'networkidle'** will timeout on sites with SSE/WebSocket/streaming connections. Use 'domcontentloaded' + explicit waits instead.
- **JS-rendered content:** Many SPAs show "Loading..." initially. Add `waitForTimeout(5000)` or poll for content to appear.
- **Memory:** Each Chromium instance uses ~300MB. Close browsers promptly after use.
- **Multiple profiles:** Use separate profile dirs to maintain independent sessions (different accounts, etc.)

## Management
```bash
# Start/stop the VNC environment
sudo systemctl start monitor-vnc
sudo systemctl stop monitor-vnc

# Check status
sudo systemctl status monitor-vnc
ps -u monitor -o pid,rss,comm

# Kill stuck Chrome instances
sudo -u monitor pkill -f "chrome.*profile-account"
```

## Dependencies
- `xvfb` — virtual framebuffer
- `x11vnc` — VNC server
- `fluxbox` — minimal window manager
- `playwright-extra` + `puppeteer-extra-plugin-stealth` (npm, installed under monitor user)
- Chromium from Playwright cache (shared with openclaw user)
