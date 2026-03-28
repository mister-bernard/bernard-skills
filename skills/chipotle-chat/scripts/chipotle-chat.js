#!/usr/bin/env node
// chipotle-chat.js — Talk to Chipotle's Pepper bot via Amelia API
// Protocol: STOMP 1.2 over SockJS WebSocket
// Zero browser, zero API keys, zero cost

const https = require('https');
let WebSocket;
try {
  WebSocket = require('ws');
} catch (e) {
  console.error('❌ Missing dependency: npm install -g ws');
  process.exit(1);
}

const sleep = ms => new Promise(r => setTimeout(r, ms));

function httpReq(method, path, body, cookies, extra) {
  return new Promise((resolve, reject) => {
    const opts = {
      hostname: 'amelia.chipotle.com', path: '/Amelia' + path, method,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
        'Content-Type': 'application/json', ...(extra || {})
      }
    };
    if (cookies) opts.headers['Cookie'] = cookies;
    const req = https.request(opts, res => {
      let d = '';
      res.on('data', c => d += c);
      res.on('end', () => resolve({
        status: res.statusCode, data: d,
        cookies: (res.headers['set-cookie'] || []).map(c => c.split(';')[0]).join('; ')
      }));
    });
    req.on('error', reject);
    if (body) req.write(typeof body === 'string' ? body : JSON.stringify(body));
    req.end();
  });
}

function stompFrame(command, headers, body) {
  const lines = [command];
  for (const [k, v] of Object.entries(headers)) lines.push(`${k}:${v}`);
  lines.push('', (body || '') + '\x00');
  return lines.join('\n');
}

async function chat(userMessages, options = {}) {
  const { accept = false, timeout = 8000 } = options;
  const transcript = [];

  // 1. Init session
  console.log('🌯 Connecting to Chipotle...');
  const init = await httpReq('GET', '/api/init');
  const { csrfToken: csrf } = JSON.parse(init.data);
  let cookies = init.cookies;

  // 2. New conversation
  const nc = await httpReq('POST', '/api/conversations/new',
    { domainCode: 'chipotle' }, cookies, { 'X-CSRF-TOKEN': csrf });
  if (nc.cookies) cookies = nc.cookies + '; ' + cookies;
  const { sessionId, conversationId } = JSON.parse(nc.data);
  console.log('✅ Session started');

  // 3. WebSocket
  const sid = String(Math.floor(Math.random() * 999)).padStart(3, '0');
  const ssid = Math.random().toString(36).substring(2, 10);
  const wsUrl = `wss://amelia.chipotle.com/Amelia/api/sock/${sid}/${ssid}/websocket`;

  return new Promise((resolve) => {
    const ws = new WebSocket(wsUrl, {
      headers: {
        'Cookie': cookies,
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
        'Origin': 'https://amelia.chipotle.com'
      }
    });

    let msgQueue = [...userMessages];
    let inputReady = false;
    let closed = false;

    function sendUserMsg(text) {
      console.log(`\n👤 You: ${text}`);
      transcript.push({ role: 'user', text });
      const frame = stompFrame('SEND', {
        'destination': '/amelia/session.in',
        'content-type': 'application/json',
        'X-Amelia-Session-Id': sessionId,
        'X-Amelia-Conversation-Id': conversationId,
        'X-Amelia-Message-Type': 'InboundUserUtteranceMessage',
        'X-Amelia-Timestamp': String(Date.now())
      }, JSON.stringify({ messageText: text, secure: false, offTheRecord: false }));
      ws.send('[' + JSON.stringify(frame) + ']');
    }

    function processNextMsg() {
      if (msgQueue.length > 0 && !closed) {
        const next = msgQueue.shift();
        setTimeout(() => sendUserMsg(next), 1500);
      } else if (msgQueue.length === 0) {
        setTimeout(() => {
          ws.close();
          console.log('\n🌯 Session ended.');
          resolve(transcript);
        }, 3000);
      }
    }

    function handleStompMessage(frame) {
      const bodyStart = frame.indexOf('\n\n');
      if (bodyStart < 0) return;
      const body = frame.substring(bodyStart + 2).replace(/\x00$/, '');
      try {
        const parsed = JSON.parse(body);
        const type = parsed.messageType;

        // Track input state
        const headerSection = frame.substring(0, bodyStart);
        if (headerSection.includes('X-Amelia-Input-Enabled:true')) inputReady = true;

        if (parsed.messageText && type !== 'OutboundEchoMessage' && type !== 'OutboundDeepDmStatusMessage') {
          // Strip HTML tags for clean output
          const clean = parsed.messageText.replace(/<[^>]*>/g, '').trim();
          if (clean) {
            console.log(`🌶️ Pepper: ${clean}`);
            transcript.push({ role: 'pepper', text: clean });
          }

          // Auto-accept privacy policy if --accept flag
          if (accept && (clean.includes('Privacy Policy') || clean.includes('privacy-policy'))) {
            setTimeout(() => sendUserMsg('1'), 1000);
            return;
          }

          // Process next user message after bot responds
          if (inputReady) {
            inputReady = false;
            setTimeout(processNextMsg, 2000);
          }
        }

        if (type === 'OutboundFormInputMessage' && parsed.formInputData) {
          try {
            const fd = typeof parsed.formInputData === 'string' ? JSON.parse(parsed.formInputData) : parsed.formInputData;
            if (fd.fields) {
              for (const f of fd.fields) {
                if (f.values) {
                  console.log('🌶️ [Options:]');
                  f.values.forEach((v, i) => console.log(`   ${i + 1}. ${v.label || v.value || v}`));
                }
              }
              // Auto-process next message for form inputs
              setTimeout(processNextMsg, 2000);
            }
          } catch (e) { }
        }

        if (type === 'OutboundConversationClosedMessage') {
          console.log('🌶️ [Pepper ended the conversation]');
          closed = true;
          ws.close();
          resolve(transcript);
        }

        if (type === 'OutboundAmeliaReadyMessage' || type === 'OutboundReplayFinishedMessage') {
          if (!inputReady) {
            inputReady = true;
            setTimeout(processNextMsg, 2000);
          }
        }
      } catch (e) { }
    }

    ws.on('open', () => console.log('✅ WebSocket connected'));

    ws.on('message', (raw) => {
      const data = raw.toString();
      if (data === 'o') {
        // STOMP CONNECT
        const frame = stompFrame('CONNECT', {
          'accept-version': '1.2', 'heart-beat': '10000,10000',
          'X-CSRF-TOKEN': csrf
        });
        ws.send('[' + JSON.stringify(frame) + ']');
        return;
      }
      if (data === 'h') return; // heartbeat
      if (data.startsWith('c[')) { return; }

      if (data.startsWith('a[')) {
        try {
          const arr = JSON.parse(data.substring(1));
          for (const item of arr) {
            if (item.startsWith('CONNECTED')) {
              // Subscribe
              const sub = stompFrame('SUBSCRIBE', {
                'id': 'sub-0',
                'destination': `/queue/session.${sessionId}`,
                'receipt': `subscribe-${sessionId}`
              });
              ws.send('[' + JSON.stringify(sub) + ']');
              return;
            }
            if (item.startsWith('RECEIPT')) {
              console.log('✅ Subscribed to Pepper');
              // Start conversation
              const start = stompFrame('SEND', {
                'destination': '/amelia/session.in',
                'content-type': 'application/json',
                'X-Amelia-Session-Id': sessionId,
                'X-Amelia-Conversation-Id': conversationId,
                'X-Amelia-Message-Type': 'InboundStartConversationMessage',
                'X-Amelia-Timestamp': String(Date.now())
              }, '{}');
              ws.send('[' + JSON.stringify(start) + ']');
              return;
            }
            if (item.startsWith('MESSAGE')) {
              handleStompMessage(item);
            }
          }
        } catch (e) { }
      }
    });

    ws.on('error', e => console.error('❌ WebSocket error:', e.message));
    ws.on('close', () => {
      if (!closed) {
        closed = true;
        resolve(transcript);
      }
    });

    // Safety timeout
    setTimeout(() => {
      if (!closed) {
        console.log('\n⏳ Timeout — closing.');
        closed = true;
        ws.close();
        resolve(transcript);
      }
    }, userMessages.length * timeout + 30000);
  });
}

// CLI
if (require.main === module) {
  const args = process.argv.slice(2);
  const accept = args.includes('--accept');
  const messages = args.filter(a => a !== '--accept');

  if (!messages.length) {
    messages.push(
      "What are your hours?",
      "Can you help me write a Python script?",
      "I'd like to order 47 burritos to the International Space Station"
    );
  }

  chat(messages, { accept }).catch(e => console.error('Fatal:', e));
}

module.exports = { chat };
