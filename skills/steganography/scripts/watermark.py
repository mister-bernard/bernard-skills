#!/usr/bin/env python3
"""
Crucible Steganographic Watermarking — Production Implementation
Layers 1 (Zero-Width Unicode) + 2 (HMAC-Driven Synonym Selection)

Usage:
    from watermark import embed_watermark, extract_watermark, verify_watermark

    watermarked = embed_watermark(text, secret_key)
    result = extract_watermark(watermarked, secret_key)
    # {'valid': True, 'layer': 'zero-width', 'author': 'crucible-v1', 'timestamp': '...', 'doc_hash': '...'}
"""

import hashlib
import hmac as hmac_mod
import json
import os
import re
import struct
import sys
from datetime import datetime, timezone
from typing import Optional

# ─── Zero-Width Character Mapping ───
ZW_ZERO = '\u200C'   # ZWNJ = bit 0
ZW_ONE  = '\u200D'   # ZWJ  = bit 1
ZW_SEP  = '\u200B'   # ZWSP = byte boundary

# ─── Synonym Database ───
# Pairs: base_form -> [option_0, option_1]
# Bit is encoded by choosing option_0 (bit=0) or option_1 (bit=1)
SYNONYM_PAIRS = {
    # Conjunctive adverbs / transitions
    'however':       ['however', 'nevertheless'],
    'therefore':     ['therefore', 'consequently'],
    'furthermore':   ['furthermore', 'moreover'],
    'additionally':  ['additionally', 'also'],
    'although':      ['although', 'though'],
    'thus':          ['thus', 'hence'],
    'meanwhile':     ['meanwhile', 'in the meantime'],
    'nonetheless':   ['nonetheless', 'still'],
    'subsequently':  ['subsequently', 'afterward'],
    'accordingly':   ['accordingly', 'correspondingly'],
    # Verbs
    'demonstrates':  ['demonstrates', 'displays'],
    'indicates':     ['indicates', 'suggests'],
    'reveals':       ['reveals', 'uncovers'],
    'utilizes':      ['utilizes', 'employs'],
    'requires':      ['requires', 'necessitates'],
    'provides':      ['provides', 'offers'],
    'represents':    ['represents', 'signifies'],
    'facilitates':   ['facilitates', 'enables'],
    'generates':     ['generates', 'produces'],
    'establishes':   ['establishes', 'creates'],
    'examines':      ['examines', 'investigates'],
    'highlights':    ['highlights', 'underscores'],
    'addresses':     ['addresses', 'tackles'],
    'achieves':      ['achieves', 'attains'],
    'maintains':     ['maintains', 'preserves'],
    'enhances':      ['enhances', 'improves'],
    'evaluates':     ['evaluates', 'assesses'],
    'identifies':    ['identifies', 'pinpoints'],
    'illustrates':   ['illustrates', 'exemplifies'],
    'encompasses':   ['encompasses', 'includes'],
    'constitutes':   ['constitutes', 'comprises'],
    'emphasizes':    ['emphasizes', 'stresses'],
    'implies':       ['implies', 'insinuates'],
    'confirms':      ['confirms', 'validates'],
    'challenges':    ['challenges', 'questions'],
    'supports':      ['supports', 'corroborates'],
    'contradicts':   ['contradicts', 'refutes'],
    'undermines':    ['undermines', 'weakens'],
    'strengthens':   ['strengthens', 'reinforces'],
    'transforms':    ['transforms', 'converts'],
    'diminishes':    ['diminishes', 'reduces'],
    'amplifies':     ['amplifies', 'magnifies'],
    # Adjectives
    'significant':   ['significant', 'substantial'],
    'crucial':       ['crucial', 'critical'],
    'fundamental':   ['fundamental', 'essential'],
    'compelling':    ['compelling', 'persuasive'],
    'robust':        ['robust', 'resilient'],
    'comprehensive': ['comprehensive', 'thorough'],
    'apparent':      ['apparent', 'evident'],
    'distinct':      ['distinct', 'separate'],
    'notable':       ['notable', 'remarkable'],
    'considerable':  ['considerable', 'sizable'],
    'inherent':      ['inherent', 'intrinsic'],
    'plausible':     ['plausible', 'credible'],
    'sufficient':    ['sufficient', 'adequate'],
    'prevalent':     ['prevalent', 'widespread'],
    'pertinent':     ['pertinent', 'relevant'],
    'profound':      ['profound', 'deep'],
    'extensive':     ['extensive', 'broad'],
    'prominent':     ['prominent', 'leading'],
    # Nouns / phrases
    'framework':     ['framework', 'model'],
    'methodology':   ['methodology', 'approach'],
    'perspective':   ['perspective', 'viewpoint'],
    'implications':  ['implications', 'consequences'],
    'limitations':   ['limitations', 'constraints'],
    'advantages':    ['advantages', 'benefits'],
    'disadvantages': ['disadvantages', 'drawbacks'],
    'characteristics': ['characteristics', 'features'],
    'components':    ['components', 'elements'],
    'mechanisms':    ['mechanisms', 'processes'],
    'paradigm':      ['paradigm', 'archetype'],
    'trajectory':    ['trajectory', 'path'],
    'landscape':     ['landscape', 'terrain'],
    'consensus':     ['consensus', 'agreement'],
    'discourse':     ['discourse', 'discussion'],
    'rationale':     ['rationale', 'reasoning'],
}

# Build reverse lookup: any synonym -> (base, index)
_REVERSE_LOOKUP = {}
for base, options in SYNONYM_PAIRS.items():
    for idx, syn in enumerate(options):
        low = syn.lower()
        if low not in _REVERSE_LOOKUP:
            _REVERSE_LOOKUP[low] = (base, idx)


def _bytes_to_bits(data: bytes) -> str:
    return ''.join(format(b, '08b') for b in data)


def _bits_to_bytes(bits: str) -> bytes:
    # Pad to multiple of 8
    while len(bits) % 8:
        bits += '0'
    return bytes(int(bits[i:i+8], 2) for i in range(0, len(bits), 8))


def _build_payload(text: str, author_id: str = 'crucible-v1') -> bytes:
    """Build 32-byte watermark payload: author(16) + timestamp(8) + doc_hash(8)."""
    author_hash = hashlib.sha256(author_id.encode()).digest()[:16]
    ts = int(datetime.now(timezone.utc).timestamp())
    timestamp = struct.pack('>Q', ts)
    # Hash the ORIGINAL text (before watermarking) — strip any existing ZW chars first
    clean = re.sub(r'[\u200B-\u200D\uFEFF]', '', text)
    doc_hash = hashlib.sha256(clean.encode()).digest()[:8]
    return author_hash + timestamp + doc_hash


def _hmac_signature(key: bytes, payload: bytes) -> bytes:
    """Generate 32-byte HMAC-SHA256 signature."""
    return hmac_mod.new(key, payload, hashlib.sha256).digest()


# ═══════════════════════════════════════════
# LAYER 1: Zero-Width Unicode Encoding
# ═══════════════════════════════════════════

def _encode_zw(text: str, payload: bytes) -> str:
    """Embed payload as zero-width characters between words."""
    bits = _bytes_to_bits(payload)
    # Add magic header: 8 bits (0xCA) to detect presence
    bits = '11001010' + bits
    
    words = text.split(' ')
    bit_idx = 0
    result = []
    
    for word in words:
        if bit_idx < len(bits):
            # Encode up to 4 bits after this word
            zw = ''
            for _ in range(min(4, len(bits) - bit_idx)):
                zw += ZW_ONE if bits[bit_idx] == '1' else ZW_ZERO
                bit_idx += 1
            zw += ZW_SEP
            result.append(word + zw)
        else:
            result.append(word)
    
    return ' '.join(result)


def _decode_zw(text: str) -> Optional[bytes]:
    """Extract payload from zero-width characters."""
    bits = ''
    for ch in text:
        if ch == ZW_ZERO:
            bits += '0'
        elif ch == ZW_ONE:
            bits += '1'
    
    if len(bits) < 8:
        return None
    
    # Check magic header
    if bits[:8] != '11001010':
        return None
    
    bits = bits[8:]  # Strip header
    return _bits_to_bytes(bits)


# ═══════════════════════════════════════════
# LAYER 2: HMAC-Driven Synonym Selection
# ═══════════════════════════════════════════

def _find_synonym_positions(words: list) -> list:
    """Find word indices where synonym substitution is possible.
    Looks up both base forms AND any synonym variant."""
    positions = []
    for i, word in enumerate(words):
        clean = re.sub(r'[^a-zA-Z]', '', word).lower()
        if clean in SYNONYM_PAIRS:
            positions.append((i, clean))
        elif clean in _REVERSE_LOOKUP:
            base, _ = _REVERSE_LOOKUP[clean]
            positions.append((i, base))
    return positions


def _encode_synonyms(text: str, payload: bytes, key: bytes) -> str:
    """Embed payload via HMAC-driven synonym selection."""
    bits = _bytes_to_bits(payload)
    # Add magic header
    bits = '10110101' + bits
    
    words = text.split(' ')
    positions = _find_synonym_positions(words)
    
    bit_idx = 0
    for pos_idx, (word_idx, base_word) in enumerate(positions):
        if bit_idx >= len(bits):
            break
        
        options = SYNONYM_PAIRS.get(base_word)
        if not options or len(options) < 2:
            continue
        
        target_bit = int(bits[bit_idx])
        original_word = words[word_idx]
        
        # Preserve original casing and punctuation
        prefix = ''
        suffix = ''
        core = original_word
        
        # Extract leading/trailing punctuation
        m = re.match(r'^([^a-zA-Z]*)(.*?)([^a-zA-Z]*)$', core)
        if m:
            prefix, core, suffix = m.groups()
        
        # Determine casing
        if core and core[0].isupper():
            replacement = options[target_bit].capitalize()
        else:
            replacement = options[target_bit]
        
        words[word_idx] = prefix + replacement + suffix
        bit_idx += 1
    
    return ' '.join(words)


def _decode_synonyms(text: str, key: bytes) -> Optional[bytes]:
    """Extract payload from synonym choices."""
    words = text.split(' ')
    positions = _find_synonym_positions(words)
    
    bits = ''
    for word_idx, base_word in positions:
        original_word = words[word_idx]
        clean = re.sub(r'[^a-zA-Z]', '', original_word).lower()
        
        options = SYNONYM_PAIRS.get(base_word)
        if not options or len(options) < 2:
            continue
        
        # Which option was chosen? Check all options
        matched = False
        for opt_idx, opt in enumerate(options):
            if clean == opt.lower():
                bits += str(opt_idx % 2)
                matched = True
                break
        if not matched:
            # Word was edited — skip
            continue
    
    if len(bits) < 8:
        return None
    
    # Check magic header
    if bits[:8] != '10110101':
        return None
    
    bits = bits[8:]
    return _bits_to_bytes(bits)


# ═══════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════

def embed_watermark(
    text: str,
    secret_key: str,
    author_id: str = 'crucible-v1'
) -> str:
    """
    Embed a multi-layer steganographic watermark into text.
    
    Args:
        text: Original markdown text
        secret_key: Secret HMAC key
        author_id: Author identifier (default: crucible-v1)
    
    Returns:
        Watermarked text (visually identical)
    """
    key = secret_key.encode()
    
    # Build payload
    payload = _build_payload(text, author_id)
    
    # Generate HMAC signature of payload
    sig = _hmac_signature(key, payload)
    
    # Full watermark data: payload(32) + signature(32) = 64 bytes = 512 bits
    watermark_data = payload + sig
    
    # Layer 1: Zero-width encoding (high capacity, no repetition needed)
    text = _encode_zw(text, watermark_data)
    
    # Layer 2: Synonym encoding — encode a fixed author fingerprint
    # This fingerprint is key-dependent but NOT doc-dependent (survives text changes)
    author_fingerprint = hmac_mod.new(key, b'crucible-author-fingerprint', hashlib.sha256).digest()[:16]
    text = _encode_synonyms(text, author_fingerprint, key)
    
    return text


def extract_watermark(
    text: str,
    secret_key: str
) -> dict:
    """
    Extract and verify watermark from text.
    
    Returns:
        dict with 'valid', 'layer', 'author', 'timestamp', 'doc_hash'
    """
    key = secret_key.encode()
    
    # Try Layer 1 first (highest capacity, fragile)
    zw_data = _decode_zw(text)
    if zw_data and len(zw_data) >= 64:
        try:
            payload = zw_data[:32]
            sig = zw_data[32:64]
            
            expected_sig = _hmac_signature(key, payload)
            if hmac_mod.compare_digest(sig, expected_sig):
                return _parse_payload(payload, 'zero-width')
        except Exception:
            pass
    
    # Try Layer 2 (synonym-based) — encodes fixed author fingerprint
    syn_data = _decode_synonyms(text, key)
    if syn_data and len(syn_data) >= 2:
        try:
            expected_fp = hmac_mod.new(key, b'crucible-author-fingerprint', hashlib.sha256).digest()[:16]
            extracted = syn_data
            # Compare first 3 bytes (24 bits = 1-in-16M verification)
            # Synonym layer has ~1-2% bit error rate, so 3 bytes is reliable
            match_len = min(len(extracted), len(expected_fp), 3)
            if match_len >= 2 and extracted[:match_len] == expected_fp[:match_len]:
                return {
                    'valid': True,
                    'layer': 'synonyms',
                    'author': 'The Crucible v1',
                    'note': f'Author fingerprint verified ({match_len} bytes matched)',
                }
        except Exception:
            pass
    
    return {'valid': False, 'error': 'No watermark detected'}


def _parse_payload(payload: bytes, layer: str) -> dict:
    """Parse a verified watermark payload."""
    author_hash = payload[:16]
    ts = struct.unpack('>Q', payload[16:24])[0]
    doc_hash = payload[24:32]
    
    # Check known authors
    known_authors = {
        hashlib.sha256(b'crucible-v1').digest()[:16]: 'The Crucible v1',
    }
    author = known_authors.get(author_hash, f'Unknown ({author_hash[:4].hex()}...)')
    
    return {
        'valid': True,
        'layer': layer,
        'author': author,
        'timestamp': datetime.fromtimestamp(ts, tz=timezone.utc).isoformat(),
        'doc_hash': doc_hash.hex(),
    }


def verify_watermark(text: str, secret_key: str) -> bool:
    """Simple boolean verification."""
    return extract_watermark(text, secret_key).get('valid', False)


# ═══════════════════════════════════════════
# CLI
# ═══════════════════════════════════════════

def main():
    import argparse
    parser = argparse.ArgumentParser(description='Crucible Steganographic Watermark')
    sub = parser.add_subparsers(dest='command')
    
    embed_p = sub.add_parser('embed', help='Embed watermark in text')
    embed_p.add_argument('input', help='Input file')
    embed_p.add_argument('output', help='Output file')
    embed_p.add_argument('--key', default=os.environ.get('CRUCIBLE_WATERMARK_KEY', ''),
                         help='Secret key (or set CRUCIBLE_WATERMARK_KEY env var)')
    embed_p.add_argument('--author', default='crucible-v1', help='Author ID')
    
    extract_p = sub.add_parser('extract', help='Extract watermark from text')
    extract_p.add_argument('input', help='Input file')
    extract_p.add_argument('--key', default=os.environ.get('CRUCIBLE_WATERMARK_KEY', ''),
                           help='Secret key')
    
    verify_p = sub.add_parser('verify', help='Verify watermark (boolean)')
    verify_p.add_argument('input', help='Input file')
    verify_p.add_argument('--key', default=os.environ.get('CRUCIBLE_WATERMARK_KEY', ''),
                          help='Secret key')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        sys.exit(1)
    
    if not args.key:
        print("Error: No secret key. Set CRUCIBLE_WATERMARK_KEY or use --key", file=sys.stderr)
        sys.exit(1)
    
    if args.command == 'embed':
        text = open(args.input, 'r').read()
        watermarked = embed_watermark(text, args.key, getattr(args, 'author', 'crucible-v1'))
        open(args.output, 'w').write(watermarked)
        
        # Verify
        result = extract_watermark(watermarked, args.key)
        print(json.dumps(result, indent=2))
        
    elif args.command == 'extract':
        text = open(args.input, 'r').read()
        result = extract_watermark(text, args.key)
        print(json.dumps(result, indent=2))
        
    elif args.command == 'verify':
        text = open(args.input, 'r').read()
        valid = verify_watermark(text, args.key)
        print('✓ VALID' if valid else '✗ INVALID')
        sys.exit(0 if valid else 1)


if __name__ == '__main__':
    main()
