# Suno Music Generation - Usage Examples

Comprehensive examples for different use cases.

## Basic Usage

### Simple Text Prompt

```bash
./scripts/generate.sh --prompt "chill lofi hip hop beats"
```

Output: 2 MP3 files in current directory

### With Output Directory

```bash
mkdir -p ~/music/suno
./scripts/generate.sh \
  --prompt "energetic rock music" \
  --output-dir ~/music/suno
```

## Custom Mode (Lyrics + Style)

### Full Custom Song

```bash
./scripts/generate.sh \
  --title "Digital Dreams" \
  --style "synthwave, electronic, 80s, retro" \
  --lyrics "Verse 1:
Neon lights in the midnight sky
Digital dreams passing by
Lost in circuits, lost in time
This electric heart of mine

Chorus:
We're living in a digital dream
Nothing's ever what it seems
Pixels dancing on the screen
In this neon-lit regime"
```

### Short Custom Track

```bash
./scripts/generate.sh \
  --title "Morning Coffee" \
  --style "jazz, smooth, relaxing" \
  --lyrics "Coffee brewing, sun is rising
Another day, so surprising
Take it slow, take your time
Life is good, feeling fine"
```

## Instrumental Tracks

### Ambient Background Music

```bash
./scripts/generate.sh \
  --prompt "ambient space music with synthesizers" \
  --instrumental
```

### Epic Orchestral

```bash
./scripts/generate.sh \
  --prompt "epic cinematic orchestral music with powerful drums and brass" \
  --instrumental \
  --model V5
```

### Study/Focus Music

```bash
./scripts/generate.sh \
  --prompt "peaceful piano music for studying and concentration" \
  --instrumental
```

## Genre Examples

### Electronic Dance Music (EDM)

```bash
./scripts/generate.sh \
  --prompt "high energy EDM with heavy bass drops and synth leads"
```

### Classical

```bash
./scripts/generate.sh \
  --prompt "baroque style classical piano piece" \
  --instrumental
```

### Hip Hop

```bash
./scripts/generate.sh \
  --title "Street Stories" \
  --style "hip hop, boom bap, 90s" \
  --lyrics "Yo, walking through the concrete jungle
Every day's a brand new struggle
Dreams bigger than the hustle
Success? Yeah I'll make it double"
```

### Country

```bash
./scripts/generate.sh \
  --prompt "upbeat country song with acoustic guitar and fiddle"
```

### Metal

```bash
./scripts/generate.sh \
  --prompt "heavy metal with aggressive guitar riffs and double bass drums"
```

## Model Comparison

### V4 (Original)

```bash
./scripts/generate.sh \
  --prompt "folk acoustic guitar" \
  --model V4
```

### V4_5 (Enhanced)

```bash
./scripts/generate.sh \
  --prompt "folk acoustic guitar" \
  --model V4_5
```

### V4_5ALL (Default - Most Versatile)

```bash
./scripts/generate.sh \
  --prompt "folk acoustic guitar" \
  --model V4_5ALL
```

### V5 (Latest)

```bash
./scripts/generate.sh \
  --prompt "folk acoustic guitar" \
  --model V5
```

## Advanced Workflows

### Batch Generation

```bash
#!/bin/bash
# Generate multiple songs

prompts=(
  "upbeat pop music"
  "sad piano ballad"
  "energetic rock anthem"
)

for prompt in "${prompts[@]}"; do
  echo "Generating: $prompt"
  ./scripts/generate.sh --prompt "$prompt" --output-dir ./batch_output
  sleep 10  # Rate limiting
done
```

### Script Integration

```bash
#!/bin/bash
# Generate and process songs

SONGS=$(./scripts/generate.sh \
  --prompt "cinematic trailer music" \
  --instrumental \
  --output-dir /tmp/suno)

# Parse output (file paths on stdout)
for song in $SONGS; do
  if [[ -f "$song" ]]; then
    echo "Processing: $song"
    # Example: Convert to different format
    # ffmpeg -i "$song" "${song%.mp3}.wav"
  fi
done
```

### With Error Handling

```bash
#!/bin/bash
set -e

OUTPUT_DIR="./music_output"
mkdir -p "$OUTPUT_DIR"

if ! ./scripts/generate.sh \
  --prompt "relaxing ambient music" \
  --output-dir "$OUTPUT_DIR" \
  --instrumental; then
  echo "Generation failed, trying again..."
  sleep 30
  ./scripts/generate.sh \
    --prompt "relaxing ambient music" \
    --output-dir "$OUTPUT_DIR" \
    --instrumental
fi

echo "Success! Files in $OUTPUT_DIR"
```

## Creative Prompts

### Mood-Based

```bash
# Happy
./scripts/generate.sh --prompt "joyful uplifting music with bright melodies"

# Sad
./scripts/generate.sh --prompt "melancholic emotional piano with strings"

# Energetic
./scripts/generate.sh --prompt "fast paced high energy music with driving rhythm"

# Relaxing
./scripts/generate.sh --prompt "calm peaceful ambient soundscape"
```

### Activity-Based

```bash
# Workout
./scripts/generate.sh --prompt "intense workout music with heavy beats"

# Sleep
./scripts/generate.sh --prompt "soft dreamy music for sleeping" --instrumental

# Meditation
./scripts/generate.sh --prompt "zen meditation music with nature sounds" --instrumental

# Party
./scripts/generate.sh --prompt "upbeat party dance music"
```

### Time Period / Style

```bash
# 80s
./scripts/generate.sh --prompt "80s synthpop with retro drum machines"

# Medieval
./scripts/generate.sh --prompt "medieval fantasy tavern music" --instrumental

# Future
./scripts/generate.sh --prompt "futuristic cyberpunk electronic music"

# Wild West
./scripts/generate.sh --prompt "western cowboy music with harmonica" --instrumental
```

## Troubleshooting Examples

### Check API Key

```bash
if [[ -z "$SUNO_API_KEY" ]]; then
  echo "API key not set!"
  export SUNO_API_KEY="your_key_here"
fi
./scripts/generate.sh --prompt "test music"
```

### Verify Dependencies

```bash
# Check Python
python3 --version

# Check requests library
python3 -c "import requests; print(f'requests {requests.__version__}')"

# Run generation
./scripts/generate.sh --prompt "test"
```

### Verbose Mode (Direct Python)

```bash
# For debugging, use Python script directly and check stderr
python3 scripts/suno-api.py \
  --prompt "test music" \
  --output-dir /tmp \
  2>&1 | tee suno_debug.log
```

## Tips

1. **Be specific** in prompts for better results
2. **Use style tags** in custom mode for genre accuracy
3. **Instrumental flag** works with both simple and custom mode
4. **Each request generates 2 songs** - you get variety
5. **Model V4_5ALL** is recommended for most use cases
6. **Rate limit** - wait 10-30s between generations
7. **Output files** are named after generated titles (may differ from your input)
