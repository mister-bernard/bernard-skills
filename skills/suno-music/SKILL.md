# Suno Music Generation

AI-powered music generation via the Suno API (sunoapi.org). Generate complete songs from text prompts or custom lyrics.

## Features

- **Simple mode**: Generate music from a text description
- **Custom mode**: Provide lyrics, style tags, and title
- **Instrumental support**: Generate music without vocals
- **Multiple models**: V4, V4_5, V4_5ALL (default), V5
- **Automatic polling**: Waits for generation to complete
- **Dual downloads**: Returns both MP3 versions (2 songs per request)
- **Clean output**: Returns file paths for easy integration

## Setup

### Requirements

- Python 3.7+
- `requests` library: `pip install requests`
- Suno API key from sunoapi.org

### Environment Variables

```bash
export SUNO_API_KEY="your_api_key_here"
```

Add to `~/.bashrc` or `~/.zshrc` for persistence.

## Usage

### Simple Mode (Text Description)

Generate music from a description:

```bash
./scripts/generate.sh --prompt "upbeat electronic dance music with heavy bass"
```

### Custom Mode (Lyrics + Style)

Provide custom lyrics and style:

```bash
./scripts/generate.sh \
  --lyrics "Verse 1: Walking down the street..." \
  --style "indie rock, acoustic, melancholic" \
  --title "City Streets"
```

### Instrumental

Generate instrumental music (no vocals):

```bash
./scripts/generate.sh \
  --prompt "epic orchestral cinematic music" \
  --instrumental
```

### Model Selection

Choose a specific model:

```bash
./scripts/generate.sh \
  --prompt "jazz fusion with saxophone" \
  --model V5
```

### Output Directory

Specify where to save MP3 files:

```bash
./scripts/generate.sh \
  --prompt "lo-fi hip hop beats" \
  --output-dir /path/to/music
```

## Python Script Direct Usage

For more control, use the Python script directly:

```bash
python scripts/suno-api.py \
  --prompt "synthwave retro 80s" \
  --model V4_5ALL \
  --output-dir ./output
```

### Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `--prompt` | Yes (simple) | Text description of the music |
| `--lyrics` | Yes (custom) | Custom lyrics for the song |
| `--style` | Yes (custom) | Genre tags and style descriptors |
| `--title` | Yes (custom) | Song title |
| `--instrumental` | No | Generate instrumental (no vocals) |
| `--model` | No | Model version (default: V4_5ALL) |
| `--output-dir` | No | Output directory (default: current dir) |

## API Details

- **Provider**: sunoapi.org
- **Generate endpoint**: `POST https://api.sunoapi.org/api/v1/generate`
- **Poll endpoint**: `GET https://api.sunoapi.org/api/v1/generate/record-info?taskId=<id>`
- **Authentication**: Bearer token in `Authorization` header
- **Returns**: 2 songs per request
- **Timeout**: 5 minutes max polling time

## Models

- **V4**: Original Suno v4
- **V4_5**: Enhanced v4.5
- **V4_5ALL**: v4.5 all-genre (default, most versatile)
- **V5**: Latest Suno v5 (experimental)

## Output

The script returns paths to downloaded MP3 files:

```
Generated songs saved:
  /path/to/output/song_title_1.mp3
  /path/to/output/song_title_2.mp3
```

Each request generates **2 variations** of the same prompt.

## Examples

### Lo-fi Study Music

```bash
./scripts/generate.sh \
  --prompt "chill lo-fi beats for studying, relaxing piano" \
  --instrumental
```

### Custom Rock Song

```bash
./scripts/generate.sh \
  --title "Broken Dreams" \
  --style "alternative rock, grunge, 90s" \
  --lyrics "Verse 1: In the darkness of my mind
I search for what I left behind
The pieces scattered on the floor
I can't take this anymore

Chorus: Broken dreams and shattered hearts
Tearing me apart, tearing me apart"
```

### Epic Trailer Music

```bash
./scripts/generate.sh \
  --prompt "epic cinematic orchestral trailer music with drums" \
  --instrumental \
  --model V5
```

## Error Handling

- Missing API key → Clear error message
- API timeout (5 min) → Exits with status
- Network errors → Retries with exponential backoff
- Invalid parameters → Validation before API call

## Notes

- Each generation costs API credits (check sunoapi.org pricing)
- Generation takes 30-90 seconds typically
- Both MP3s are downloaded automatically
- Files are named after the generated song titles
- Callback URL is set to `https://YOUR_DOMAIN.com/api/webhook` (required by API)

## Integration

Use in scripts or other tools:

```bash
# Generate and store paths
SONGS=$(./scripts/generate.sh --prompt "happy birthday song" --output-dir /tmp)

# Process the files
for song in $(echo "$SONGS" | grep ".mp3"); do
  echo "Processing: $song"
  # Do something with the song
done
```

## Troubleshooting

**"API key not found"**
→ Set `SUNO_API_KEY` environment variable

**"Generation timeout"**
→ Suno API may be overloaded, try again later

**"Invalid mode"**
→ Use either `--prompt` (simple) OR `--lyrics + --style + --title` (custom)

**"Failed to download MP3"**
→ Check internet connection and file permissions in output directory
