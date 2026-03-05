#!/usr/bin/env bash
# Hume Octave TTS wrapper
# Usage: hume-tts.sh "text" output.mp3 ["voice description"]
set -euo pipefail

TEXT="$1"
OUTPUT="${2:-/tmp/hume-output.mp3}"
DESCRIPTION="${3:-}"
TMPJSON=$(mktemp /tmp/hume-resp-XXXXX.json)
trap "rm -f $TMPJSON" EXIT

if [ -z "$HUME_API_KEY" ]; then
  echo "Error: HUME_API_KEY not set" >&2
  exit 1
fi

# Build JSON payload
python3 -c "
import json, sys
text, desc = sys.argv[1], sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] else ''
body = {'utterances': [{'text': text}], 'format': {'type': 'mp3'}, 'num_generations': 1}
if desc:
    body['utterances'][0]['description'] = desc
json.dump(body, sys.stdout)
" "$TEXT" "$DESCRIPTION" > /tmp/hume-payload.json

curl -s -X POST "https://api.hume.ai/v0/tts" \
  -H "X-Hume-Api-Key: $HUME_API_KEY" \
  -H "Content-Type: application/json" \
  -d @/tmp/hume-payload.json \
  -o "$TMPJSON"

# Extract base64 audio and decode
python3 -c "
import json, base64, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
if 'generations' in data and len(data['generations']) > 0:
    audio_b64 = data['generations'][0]['audio']
    with open(sys.argv[2], 'wb') as f:
        f.write(base64.b64decode(audio_b64))
    print(sys.argv[2])
    gen_id = data['generations'][0].get('generation_id', 'unknown')
    print(f'generation_id: {gen_id}')
else:
    print(json.dumps(data, indent=2), file=sys.stderr)
    sys.exit(1)
" "$TMPJSON" "$OUTPUT"
