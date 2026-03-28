#!/usr/bin/env node
"use strict";

require("dotenv").config({ path: __dirname + "/.env" });
const express = require("express");
const crypto = require("crypto");
const Telnyx = require("telnyx");

// ── Config ──────────────────────────────────────────────────────────────
const PORT = parseInt(process.env.WEBHOOK_PORT || "8443", 10);
const TELNYX_API_KEY = process.env.TELNYX_API_KEY;
const TELNYX_PUBLIC_KEY = process.env.TELNYX_PUBLIC_KEY || "";
const OPENCLAW_GATEWAY_URL = process.env.OPENCLAW_GATEWAY_URL || "http://127.0.0.1:18789";
const OPENCLAW_GATEWAY_TOKEN = process.env.OPENCLAW_GATEWAY_TOKEN;
const OPENCLAW_AGENT_ID = process.env.OPENCLAW_AGENT_ID || "main";
const BOT_NUMBER = process.env.BOT_NUMBER || "+1XXXXXXXXXX";
const MODEL_OVERRIDE = process.env.OPENCLAW_MODEL_OVERRIDE || "";

if (!TELNYX_API_KEY) throw new Error("TELNYX_API_KEY required");
if (!OPENCLAW_GATEWAY_TOKEN) throw new Error("OPENCLAW_GATEWAY_TOKEN required");

const telnyx = Telnyx(TELNYX_API_KEY);
const app = express();

// Raw body needed for signature verification
app.use("/webhook", express.raw({ type: "*/*" }));
app.use(express.json());

const log = (msg) => console.error(`[${new Date().toISOString()}] ${msg}`);

// ── Signature verification (using Telnyx SDK) ──────────────────────────
const { TelnyxWebhook } = require("telnyx/webhooks");
let webhookVerifier = null;
if (TELNYX_PUBLIC_KEY) {
  try {
    // Raw 32-byte Ed25519 public key from Telnyx Mission Control /v2/public_key
    webhookVerifier = new TelnyxWebhook(TELNYX_PUBLIC_KEY);
  } catch (e) {
    log(`⚠️ Failed to init webhook verifier: ${e.message}`);
  }
}

function verifySignature(req) {
  if (!webhookVerifier) {
    log("⚠️  Webhook verifier not configured - signature verification DISABLED");
    return true;
  }
  try {
    const payload = typeof req.body === "string" ? req.body : req.body.toString("utf8");
    webhookVerifier.verify(payload, req.headers);
    return true;
  } catch (e) {
    log(`❌ Signature verification failed: ${e.message}`);
    return false;
  }
}

// ── Send to OpenClaw gateway ────────────────────────────────────────────
async function askOpenClaw(from, to, text) {
  const url = `${OPENCLAW_GATEWAY_URL}/v1/chat/completions`;
  const body = {
    model: `openclaw:${OPENCLAW_AGENT_ID}`,
    user: `phone:${from}`,
    messages: [
      { role: "user", content: `[SMS from ${from}] ${text}` }
    ]
  };

  const resp = await fetch(url, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${OPENCLAW_GATEWAY_TOKEN}`,
      "Content-Type": "application/json",
      "x-openclaw-agent-id": OPENCLAW_AGENT_ID
    },
    body: JSON.stringify(body)
  });

  if (!resp.ok) {
    const err = await resp.text();
    throw new Error(`Gateway ${resp.status}: ${err}`);
  }

  const data = await resp.json();
  return data.choices?.[0]?.message?.content || "";
}

// ── Send SMS reply via Telnyx REST API ──────────────────────────────────
async function sendSMS(from, to, text) {
  const chunks = [];
  let remaining = text;
  while (remaining.length > 0) {
    chunks.push(remaining.slice(0, 1500));
    remaining = remaining.slice(1500);
  }

  for (const chunk of chunks) {
    const resp = await fetch("https://api.telnyx.com/v2/messages", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${TELNYX_API_KEY}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({ from, to, text: chunk })
    });
    if (!resp.ok) {
      const err = await resp.text();
      throw new Error(`Telnyx send failed ${resp.status}: ${err}`);
    }
  }
}

// ── Health check on GET /webhook ─────────────────────────────────────────
app.get("/webhook", (req, res) => res.json({ ok: true, service: "telnyx-sms" }));

// ── Webhook handler ─────────────────────────────────────────────────────
app.post("/webhook", async (req, res) => {
  // Verify signature BEFORE processing
  if (!verifySignature(req)) {
    log("🚨 Webhook rejected - invalid signature");
    return res.sendStatus(403);
  }

  // Acknowledge immediately
  res.sendStatus(200);

  let payload;
  try {
    payload = typeof req.body === "string" ? JSON.parse(req.body) : 
              Buffer.isBuffer(req.body) ? JSON.parse(req.body.toString()) : req.body;
  } catch (e) {
    log(`Failed to parse webhook body: ${e.message}`);
    return;
  }

  const data = payload?.data;
  if (!data) return;

  const eventType = data.event_type || payload.data?.event_type;
  const msgData = data.payload || data;

  // Only process inbound messages
  if (eventType !== "message.received") {
    log(`Ignoring event: ${eventType}`);
    return;
  }

  const from = msgData.from?.phone_number;
  const to = msgData.to?.[0]?.phone_number || BOT_NUMBER;
  const text = msgData.text;

  if (!from || !text) {
    log(`Missing from/text in message`);
    return;
  }

  log(`SMS from ${from} → ${to}: ${text.slice(0, 80)}...`);

  // Auto-forward verification codes directly to G on Telegram
  if (/verif|code|otp|one.time/i.test(text) && /\d{4,8}/.test(text)) {
    try {
      const TELEGRAM_TOKEN = process.env.TELEGRAM_BOT_TOKEN;
      if (TELEGRAM_TOKEN) {
        const tgMsg = `📲 SMS verification code received\nFrom: \`${from}\`\n\n\`${text}\``;
        await fetch(`https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ chat_id: "YOUR_TELEGRAM_CHAT_ID", text: tgMsg, parse_mode: "Markdown" })
        });
        log(`Forwarded verification code to Telegram`);
      }
    } catch (tgErr) {
      log(`Failed to forward verification code to Telegram: ${tgErr.message}`);
    }
  }

  try {
    const reply = await askOpenClaw(from, to, text);
    if (reply && reply !== "NO_REPLY" && reply !== "HEARTBEAT_OK" && !reply.startsWith("NO_REPLY") && reply.trim() !== "") {
      await sendSMS(to, from, reply);
      log(`Replied to ${from} (${reply.length} chars)`);
    } else {
      log(`No reply for ${from}`);
    }
  } catch (e) {
    log(`Error processing SMS from ${from}: ${e.message}`);
  }
});

// ── Health check ────────────────────────────────────────────────────────
app.get("/health", (req, res) => {
  res.json({ ok: true, bot: BOT_NUMBER, uptime: process.uptime(), signatureVerification: !!TELNYX_PUBLIC_KEY });
});

// ── Start ───────────────────────────────────────────────────────────────
app.listen(PORT, "0.0.0.0", () => {
  log(`Telnyx SMS webhook listening on 0.0.0.0:${PORT}`);
  log(`Bot number: ${BOT_NUMBER}`);
  log(`Webhook URL: http://YOUR_SERVER_IP:${PORT}/webhook`);
  log(`Signature verification: ${TELNYX_PUBLIC_KEY ? 'ENABLED ✅' : 'DISABLED ⚠️'}`);
});
