# Steganography Skill — Crucible Text Watermarking

## Overview
Embed invisible, cryptographically-verifiable watermarks in Crucible synthesis documents.
Two-layer defense: zero-width Unicode (fragile, high-capacity) + HMAC-driven synonym selection (robust, medium-capacity).

## Quick Usage

### Embed watermark
```bash
python3 skills/steganography/scripts/watermark.py embed input.md output.md
# Uses CRUCIBLE_WATERMARK_KEY env var
```

### Extract/verify watermark
```bash
python3 skills/steganography/scripts/watermark.py extract document.md
python3 skills/steganography/scripts/watermark.py verify document.md
```

### Python API
```python
from watermark import embed_watermark, extract_watermark, verify_watermark

watermarked = embed_watermark(text, secret_key)
result = extract_watermark(watermarked, secret_key)
# {'valid': True, 'layer': 'zero-width', 'author': 'The Crucible v1', 'timestamp': '...', 'doc_hash': '...'}
```

## Architecture

### Layer 1: Zero-Width Unicode (Fragile)
- Inserts invisible ZW chars (U+200C=0, U+200D=1, U+200B=separator) between words
- Encodes full 64-byte payload: author(16) + timestamp(8) + doc_hash(8) + HMAC sig(32)
- **Survives:** copy-paste, markdown rendering, UTF-8 roundtrip
- **Destroyed by:** Unicode normalization, `strip()`, regex cleanup

### Layer 2: Synonym Selection (Robust)  
- Chooses between equivalent words (however/nevertheless, demonstrates/illustrates, etc.)
- 76 synonym pairs, HMAC-driven selection encodes author fingerprint
- **Survives:** copy-paste, ZW stripping, minor edits, reformatting
- **Destroyed by:** AI paraphrasing, complete rewrite

## Integration with Crucible Pipeline

After synthesizing a debate, watermark before publishing:
```python
import os, sys
sys.path.insert(0, 'skills/steganography/scripts')
from watermark import embed_watermark

text = open('synthesis.md').read()
watermarked = embed_watermark(text, os.environ['CRUCIBLE_WATERMARK_KEY'])
open('synthesis.md', 'w').write(watermarked)
```

## Secret Key
- Stored in `~/.openclaw/.env` as `CRUCIBLE_WATERMARK_KEY`
- **NEVER commit to git or expose publicly**
- Plan: silent deployment for 6 months, then public algorithm disclosure to prove authorship

## Test Suite
```bash
python3 skills/steganography/tests/test_watermark.py
# 12 tests: roundtrips, copy-paste survival, ZW strip fallback, wrong key rejection, markdown preservation
```

## Files
```
skills/steganography/
├── SKILL.md              ← This file
├── scripts/
│   └── watermark.py      ← Main implementation (Layer 1 + Layer 2)
└── tests/
    └── test_watermark.py  ← 12-test suite (all passing)
```

## Limitations
- Minimum document size: ~150 words for Layer 1 (512 bits needed)
- Layer 2 capacity: ~1 bit per synonym position (need 40+ synonym-eligible words)
- No Layer 3 (statistical) in v1 — would require generation-time control
- After public disclosure, motivated adversaries can strip both layers (but at that point they've created a derivative work)
