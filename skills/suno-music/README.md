# Suno Music Generation Skill

Quick-start guide for generating AI music with Suno.

## Setup (One-time)

1. Install Python dependencies:
   ```bash
   pip install requests
   ```

2. Set your API key:
   ```bash
   export SUNO_API_KEY="your_api_key_from_sunoapi.org"
   ```
   
   Add to `~/.bashrc` to persist.

## Quick Examples

**Generate from description:**
```bash
./scripts/generate.sh --prompt "upbeat electronic dance music"
```

**Custom song with lyrics:**
```bash
./scripts/generate.sh \
  --title "My Song" \
  --style "rock, energetic" \
  --lyrics "Verse 1: Hello world..."
```

**Instrumental:**
```bash
./scripts/generate.sh --prompt "epic orchestral" --instrumental
```

See **SKILL.md** for full documentation.

## Files

- `SKILL.md` — Complete documentation
- `scripts/generate.sh` — Main wrapper script (use this)
- `scripts/suno-api.py` — Python API client (can use directly)

## Output

Generates **2 MP3 files** per request, saved to current directory (or `--output-dir`).

## Cost

Each generation uses API credits. Check sunoapi.org for pricing.
