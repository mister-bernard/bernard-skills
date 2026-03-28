/**
 * Hotline Voice Command Handler
 * 
 * Receives audio from PWA or iOS Shortcuts, transcribes via Deepgram,
 * and delivers to OpenClaw agent for processing.
 * 
 * Usage in Express server:
 * 
 * const hotlineHandler = require('./hotline-handler');
 * app.post('/api/hotline', hotlineHandler);
 * app.post('/voice', hotlineHandler);
 */

const fs = require('fs');
const { exec } = require('child_process');
const FormData = require('form-data');
const formidable = require('formidable').formidable;

// Configuration (set these in your .env)
const HOTLINE_API_KEY = process.env.HOTLINE_API_KEY || 'YOUR_HOTLINE_API_KEY';
const HOTLINE_RATE_LIMIT_MS = 5000; // 5 seconds between calls
const AGENT_ID = 'opus-dm'; // Change to your agent ID
const REPLY_CHANNEL = 'telegram'; // Change to your channel
const REPLY_TARGET = 'YOUR_TELEGRAM_CHAT_ID'; // Change to your chat ID

// Rate limiting map
const hotlineRateLimit = new Map();

// Helper: Extract auth from request
function getHotlineAuth(req, parsedUrl) {
  // Bearer token
  const authHeader = req.headers['authorization'];
  if (authHeader && authHeader.startsWith('Bearer ')) {
    return authHeader.substring(7);
  }
  
  // X-API-Key header
  const apiKeyHeader = req.headers['x-api-key'];
  if (apiKeyHeader) {
    return apiKeyHeader;
  }
  
  // Query param
  const keyParam = parsedUrl.searchParams.get('key');
  if (keyParam) {
    return keyParam;
  }
  
  return null;
}

// Helper: Process audio and deliver to agent
async function processHotlineAudio(audioFile, location, duration, res) {
  const audioPath = audioFile.filepath;
  
  // Transcribe audio using Deepgram (primary) or OpenAI Whisper (fallback)
  let transcript = null;
  const deepgramKey = process.env.DEEPGRAM_API_KEY;
  const openaiKey = process.env.OPENAI_WHISPER_API_KEY || process.env.OPENAI_API_KEY;
  
  // Try Deepgram first
  if (deepgramKey) {
    try {
      const audioBuffer = fs.readFileSync(audioPath);
      const deepgramResponse = await fetch('https://api.deepgram.com/v1/listen?model=nova-2&smart_format=true', {
        method: 'POST',
        headers: {
          'Authorization': `Token ${deepgramKey}`,
          'Content-Type': audioFile.mimetype || 'audio/webm'
        },
        body: audioBuffer
      });

      if (deepgramResponse.ok) {
        const deepgramResult = await deepgramResponse.json();
        transcript = deepgramResult.results?.channels?.[0]?.alternatives?.[0]?.transcript;
      } else {
        const errorText = await deepgramResponse.text();
        console.error('[Hotline] Deepgram API error:', deepgramResponse.status, errorText);
      }
    } catch (transcribeErr) {
      console.error('[Hotline] Deepgram error:', transcribeErr);
    }
  }
  
  // Fallback to OpenAI Whisper if Deepgram failed
  if (!transcript && openaiKey) {
    try {
      const whisperFormData = new FormData();
      whisperFormData.append('file', fs.createReadStream(audioPath), {
        filename: 'audio.webm',
        contentType: audioFile.mimetype || 'audio/webm'
      });
      whisperFormData.append('model', 'whisper-1');

      const whisperResponse = await fetch('https://api.openai.com/v1/audio/transcriptions', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${openaiKey}`,
          ...whisperFormData.getHeaders()
        },
        body: whisperFormData
      });

      if (whisperResponse.ok) {
        const whisperResult = await whisperResponse.json();
        transcript = whisperResult.text;
      } else {
        const errorText = await whisperResponse.text();
        console.error('[Hotline] Whisper API error:', whisperResponse.status, errorText);
      }
    } catch (transcribeErr) {
      console.error('[Hotline] Transcription error:', transcribeErr);
    }
  }

  // Send to OpenClaw agent via CLI (async fire-and-forget)
  try {
    let agentMessage = transcript || '(audio file)';
    
    // Add location context if available
    if (location) {
      agentMessage += `\n\n[Location: ${location.lat.toFixed(6)}, ${location.lng.toFixed(6)} - https://maps.google.com/maps?q=${location.lat},${location.lng}]`;
    }
    
    // Execute openclaw agent command to deliver to configured target
    const openclawPath = process.env.OPENCLAW_BIN_PATH || '/home/openclaw/.npm-global/bin/openclaw';
    const cmd = `${openclawPath} agent --agent ${AGENT_ID} --message ${JSON.stringify(agentMessage)} --deliver --reply-channel ${REPLY_CHANNEL} --reply-to ${REPLY_TARGET} --json`;
    
    exec(cmd, {
      env: { 
        ...process.env, 
        HOME: process.env.HOME || '/home/openclaw',
        PATH: process.env.PATH || '/home/openclaw/.npm-global/bin:/usr/local/bin:/usr/bin:/bin'
      }
    }, (err, stdout, stderr) => {
      if (err) {
        console.error('[Hotline] Agent error:', err.message);
      } else {
        console.log('[Hotline] Agent response:', stdout.substring(0, 200));
      }
    });
    
    console.log('[Hotline] Message queued for agent');
  } catch (agentErr) {
    console.error('[Hotline] Agent error:', agentErr.message);
  }

  // Clean up temp file after 1 minute
  setTimeout(() => {
    try {
      fs.unlinkSync(audioPath);
    } catch (e) {
      // Ignore cleanup errors
    }
  }, 60000);

  // Return success
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ 
    ok: true, 
    message: 'Received and forwarded',
    transcribed: !!transcript,
    location: !!location
  }));
}

// Main request handler
async function handleHotlineAPI(req, res) {
  const parsedUrl = new URL(req.url, `http://${req.headers.host}`);
  
  // Auth check
  const apiKey = getHotlineAuth(req, parsedUrl);
  if (apiKey !== HOTLINE_API_KEY) {
    res.writeHead(401, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Unauthorized' }));
    return;
  }

  // Rate limiting
  const now = Date.now();
  const lastCall = hotlineRateLimit.get(apiKey) || 0;
  if (now - lastCall < HOTLINE_RATE_LIMIT_MS) {
    res.writeHead(429, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ 
      error: 'Rate limit exceeded', 
      retryAfter: Math.ceil((HOTLINE_RATE_LIMIT_MS - (now - lastCall)) / 1000) 
    }));
    return;
  }
  hotlineRateLimit.set(apiKey, now);

  // Check for GPS in headers (iOS Shortcuts pattern)
  let locationFromHeaders = null;
  const latHeader = req.headers['x-location-lat'];
  const lonHeader = req.headers['x-location-lon'];
  
  if (latHeader && lonHeader) {
    locationFromHeaders = {
      lat: parseFloat(latHeader),
      lng: parseFloat(lonHeader),
      accuracy: null,
      timestamp: Date.now(),
      source: 'headers'
    };
  }

  // Check content type - if it's not multipart, accept raw binary
  const contentType = req.headers['content-type'] || '';
  const isMultipart = contentType.includes('multipart/form-data');

  if (!isMultipart) {
    // Raw binary audio upload (iOS Shortcuts workaround)
    const chunks = [];
    req.on('data', chunk => chunks.push(chunk));
    req.on('end', async () => {
      const audioBuffer = Buffer.concat(chunks);
      if (audioBuffer.length === 0) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'No audio data provided' }));
        return;
      }

      const audioPath = `/tmp/hotline-${Date.now()}.webm`;
      fs.writeFileSync(audioPath, audioBuffer);
      
      const audioFile = {
        filepath: audioPath,
        mimetype: contentType || 'audio/webm',
        size: audioBuffer.length
      };
      
      await processHotlineAudio(audioFile, locationFromHeaders, null, res);
    });
    return;
  }

  // Parse multipart form data (PWA path)
  const form = formidable({
    uploadDir: '/tmp',
    keepExtensions: true,
    maxFileSize: 50 * 1024 * 1024, // 50MB max
    filename: (name, ext) => `hotline-${Date.now()}${ext}`
  });

  form.parse(req, async (err, fields, files) => {
    if (err) {
      console.error('[Hotline] Form parse error:', err);
      res.writeHead(400, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'Invalid form data' }));
      return;
    }

    try {
      // Extract fields
      const audioFile = files.audio?.[0] || files.audio || files.file?.[0] || files.file;
      const duration = fields.duration?.[0] || fields.duration || '0';
      const locationStr = fields.location?.[0] || fields.location;
      
      if (!audioFile) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'No audio file provided' }));
        return;
      }

      // Location priority: headers > FormData
      let location = locationFromHeaders;
      
      if (!location && locationStr) {
        try {
          location = JSON.parse(locationStr);
          location.source = 'formdata';
        } catch (e) {
          console.warn('[Hotline] Could not parse location:', e);
        }
      }

      await processHotlineAudio(audioFile, location, duration, res);
    } catch (error) {
      console.error('[Hotline] Processing error:', error);
      res.writeHead(500, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'Internal server error' }));
    }
  });
}

module.exports = handleHotlineAPI;
