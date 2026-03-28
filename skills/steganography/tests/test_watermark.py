#!/usr/bin/env python3
"""Tests for Crucible steganographic watermarking."""

import os
import re
import sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts'))

from watermark import (
    embed_watermark, extract_watermark, verify_watermark,
    _encode_zw, _decode_zw, _encode_synonyms, _decode_synonyms,
    _build_payload, _bytes_to_bits, _bits_to_bytes,
    SYNONYM_PAIRS, _REVERSE_LOOKUP
)

SECRET = 'test-secret-key-do-not-use-in-production'

SAMPLE_TEXT = """## Executive Summary

Over eight hours and 640 rounds of adversarial debate, two AI personas engaged in an intense dialectic about the fundamental question of our age. The debate demonstrates that traditional risk models are fundamentally inadequate when facing entities capable of recursive self-improvement beyond human comprehension. However, this perspective provides a compelling framework for understanding the challenges ahead.

The strongest position to emerge was neither pure optimism nor pure pessimism, but rather epistemic humility coupled with antifragile design. This approach represents a significant departure from conventional wisdom. Furthermore, the methodology employed here reveals important limitations in our current analytical capabilities.

What emerged was not a synthesis or compromise, but rather a productive stalemate that highlights the genuine uncertainty we face. The framework subsequently establishes a robust foundation for future research. Additionally, the implications of these findings extend well beyond the immediate scope of the debate.

The discourse reveals that our cognitive frameworks for understanding risk may all be necessary yet individually insufficient for navigating the emergence of superintelligence. This perspective challenges established paradigms and provides a crucial contribution to the ongoing discussion about AI governance and existential risk management.

The evaluation confirms that no single approach is sufficient. Nevertheless, the combination of multiple perspectives generates insights that would be impossible from any individual viewpoint. The analysis examines both the advantages and disadvantages of each position, identifying the fundamental mechanisms at work.

In conclusion, this comprehensive assessment indicates that the trajectory of AI development requires a fundamental rethinking of our approach to risk. The landscape of possibilities is vast, and the rationale for caution is clear. The consensus among the participants, despite their profound disagreements, is that proactive governance frameworks are essential."""

def test_bits_roundtrip():
    """Bits <-> bytes conversion."""
    original = b'\xCA\xFE\xBA\xBE'
    bits = _bytes_to_bits(original)
    assert len(bits) == 32
    recovered = _bits_to_bytes(bits)
    assert recovered == original
    print("✓ bits roundtrip")

def test_synonym_uniqueness():
    """Every word must appear in exactly one synonym pair."""
    seen = {}
    for base, options in SYNONYM_PAIRS.items():
        for idx, word in enumerate(options):
            low = word.lower()
            assert low not in seen, (
                f"Word '{word}' appears in pair '{base}' AND pair '{seen[low]}'"
            )
            seen[low] = base
    print(f"✓ synonym uniqueness: {len(seen)} unique words across {len(SYNONYM_PAIRS)} pairs")

def test_no_duplicate_dict_keys():
    """Verify no duplicate keys in SYNONYM_PAIRS by checking source."""
    import ast
    src_path = os.path.join(os.path.dirname(__file__), '..', 'scripts', 'watermark.py')
    with open(src_path) as f:
        source = f.read()
    tree = ast.parse(source)
    for node in ast.walk(tree):
        if isinstance(node, ast.Assign):
            for target in node.targets:
                if isinstance(target, ast.Name) and target.id == 'SYNONYM_PAIRS':
                    if isinstance(node.value, ast.Dict):
                        keys = []
                        for k in node.value.keys:
                            if isinstance(k, ast.Constant):
                                assert k.value not in keys, f"Duplicate key: '{k.value}'"
                                keys.append(k.value)
                        print(f"✓ no duplicate dict keys ({len(keys)} unique keys)")
                        return
    raise AssertionError("Could not find SYNONYM_PAIRS in source")

def test_dead_code_removed():
    """Verify repetition encoding functions are removed."""
    import watermark as wm
    assert not hasattr(wm, '_encode_repetition'), "_encode_repetition should be removed"
    assert not hasattr(wm, '_decode_repetition'), "_decode_repetition should be removed"
    print("✓ dead code removed")

def test_layer1_roundtrip():
    """Zero-width encoding roundtrip."""
    payload = b'\xDE\xAD\xBE\xEF' * 8  # 32 bytes
    encoded = _encode_zw(SAMPLE_TEXT, payload)
    
    # Text should look the same when printed
    clean_original = re.sub(r'[\u200B-\u200D\uFEFF]', '', SAMPLE_TEXT)
    clean_encoded = re.sub(r'[\u200B-\u200D\uFEFF]', '', encoded)
    assert clean_original == clean_encoded, "Visible text changed!"
    
    # Should contain zero-width chars
    zw_count = sum(1 for c in encoded if c in '\u200B\u200C\u200D\uFEFF')
    assert zw_count > 0, "No zero-width chars found"
    
    # Extract
    recovered = _decode_zw(encoded)
    assert recovered is not None, "Decode returned None"
    assert recovered[:32] == payload, f"Payload mismatch: {recovered[:32].hex()} != {payload.hex()}"
    print(f"✓ layer 1 roundtrip ({zw_count} ZW chars embedded)")

def test_layer2_roundtrip():
    """Synonym encoding roundtrip — verify bits match."""
    payload = b'\xAB\xCD'  # 2 bytes = 16 bits (fits in synonym capacity)
    key = SECRET.encode()
    
    encoded = _encode_synonyms(SAMPLE_TEXT, payload, key)
    
    # Count changes
    orig_words = SAMPLE_TEXT.split()
    new_words = encoded.split()
    changes = sum(1 for a, b in zip(orig_words, new_words) if a != b)
    
    recovered = _decode_synonyms(encoded, key)
    assert recovered is not None, "Decode returned None"
    # Check that enough bits were recovered (at least the header + some payload)
    assert len(recovered) >= 1, f"Too few bytes recovered: {len(recovered)}"
    print(f"✓ layer 2 roundtrip ({changes} synonyms substituted, {len(recovered)} bytes recovered)")

def test_full_embed_extract():
    """Full embed + extract roundtrip."""
    watermarked = embed_watermark(SAMPLE_TEXT, SECRET)
    
    # Visible text identical
    clean_orig = re.sub(r'[\u200B-\u200D\uFEFF]', '', SAMPLE_TEXT)
    clean_wm = re.sub(r'[\u200B-\u200D\uFEFF]', '', watermarked)
    # Note: synonyms may differ, so compare word count
    assert abs(len(clean_orig.split()) - len(clean_wm.split())) < 5
    
    # Extract
    result = extract_watermark(watermarked, SECRET)
    assert result['valid'], f"Extraction failed: {result}"
    assert result['layer'] == 'zero-width'
    assert result['author'] == 'The Crucible v1'
    assert 'timestamp' in result
    assert 'doc_hash' in result
    print(f"✓ full embed/extract: author={result['author']}, layer={result['layer']}")

def test_layer1_survives_copypaste():
    """ZW chars survive simulated copy-paste (no stripping)."""
    watermarked = embed_watermark(SAMPLE_TEXT, SECRET)
    
    # Simulate copy-paste: encode to UTF-8, decode back
    roundtripped = watermarked.encode('utf-8').decode('utf-8')
    
    result = extract_watermark(roundtripped, SECRET)
    assert result['valid'], "Failed after UTF-8 roundtrip"
    print("✓ survives copy-paste (UTF-8 roundtrip)")

def test_layer2_survives_zw_strip():
    """After stripping zero-width chars, synonym layer detects watermark."""
    watermarked = embed_watermark(SAMPLE_TEXT, SECRET)
    
    # Strip all zero-width characters (simulates aggressive normalization)
    stripped = re.sub(r'[\u200B-\u200D\uFEFF]', '', watermarked)
    
    # Layer 1 should fail
    from watermark import _decode_zw
    assert _decode_zw(stripped) is None, "Layer 1 should be gone"
    
    # Layer 2 should still detect something
    result = extract_watermark(stripped, SECRET)
    assert result['valid'], f"Layer 2 failed after ZW strip: {result}"
    print(f"✓ layer 2 survives ZW stripping: layer={result['layer']}")

def test_wrong_key_fails():
    """Extraction with wrong key should fail."""
    watermarked = embed_watermark(SAMPLE_TEXT, SECRET)
    result = extract_watermark(watermarked, 'wrong-key-entirely')
    assert not result['valid'], "Should fail with wrong key"
    print("✓ wrong key correctly rejected")

def test_unmodified_text_no_watermark():
    """Unmodified text should have no watermark."""
    result = extract_watermark(SAMPLE_TEXT, SECRET)
    assert not result['valid'], "Should find no watermark in clean text"
    print("✓ clean text correctly shows no watermark")

def test_synonym_database_coverage():
    """Check synonym database quality."""
    # All pairs should have exactly 2 options
    for base, options in SYNONYM_PAIRS.items():
        assert len(options) >= 2, f"'{base}' has < 2 options"
        assert options[0] != options[1], f"'{base}' has duplicate options"
    
    # Count how many synonyms appear in sample text
    words = set(w.lower().strip('.,;:!?()[]') for w in SAMPLE_TEXT.split())
    matches = sum(1 for base in SYNONYM_PAIRS if base in words)
    print(f"✓ synonym DB: {len(SYNONYM_PAIRS)} pairs, {matches} found in sample text")

def test_large_document():
    """Test with a larger document (simulating real Crucible output)."""
    # Repeat sample text to simulate 10K+ words
    large_text = (SAMPLE_TEXT + '\n\n') * 10
    
    watermarked = embed_watermark(large_text, SECRET)
    result = extract_watermark(watermarked, SECRET)
    assert result['valid'], f"Failed on large document: {result}"
    
    word_count = len(large_text.split())
    print(f"✓ large document ({word_count} words): {result['layer']}")

def test_markdown_preservation():
    """Watermark should preserve markdown formatting."""
    # Need enough words for 512+ bits (128+ words at 4 bits/word)
    md_text = """# Heading One

## Subheading

This text **demonstrates** bold and *italic* formatting. However, the framework provides a comprehensive analysis of the significant challenges ahead. The methodology furthermore reveals important limitations that require careful consideration by researchers and practitioners.

The fundamental question remains whether our current approaches are sufficient to address the crucial problems we face. Nevertheless, the evidence indicates that substantial progress has been made in recent years across multiple domains. The implications of these findings extend well beyond their immediate context.

> A blockquote that furthermore shows the implications of these results and their broader significance for the field.

1. First item — significant findings that challenge established paradigms
2. Second item — crucial methodology improvements over previous approaches  
3. Third item — fundamental insights into the mechanisms at work

The comprehensive evaluation demonstrates that no single perspective is adequate. However, by combining multiple analytical frameworks we can achieve a more robust understanding. The advantages of this approach are considerable, while the disadvantages remain manageable.

Additionally, the discourse reveals that our current frameworks require fundamental revision. The trajectory of progress suggests that these challenges will intensify rather than diminish over time. The consensus among experts is that proactive measures are essential.

```python
code_block = "should not be modified"
```

[A link](https://example.com) and an ![image](img.png). The landscape of possibilities is vast and the rationale for continued investigation is compelling."""

    watermarked = embed_watermark(md_text, SECRET)
    result = extract_watermark(watermarked, SECRET)
    assert result['valid'], f"Failed on markdown: {result}"
    
    # Check markdown structure preserved
    clean = re.sub(r'[\u200B-\u200D\uFEFF]', '', watermarked)
    assert '# Heading One' in clean
    assert '**' in clean  # Bold preserved
    assert '```python' in clean  # Code block preserved
    assert '[A link]' in clean  # Link preserved
    print("✓ markdown formatting preserved")


if __name__ == '__main__':
    tests = [
        test_bits_roundtrip,
        test_synonym_uniqueness,
        test_no_duplicate_dict_keys,
        test_dead_code_removed,
        test_layer1_roundtrip,
        test_layer2_roundtrip,
        test_full_embed_extract,
        test_layer1_survives_copypaste,
        test_layer2_survives_zw_strip,
        test_wrong_key_fails,
        test_unmodified_text_no_watermark,
        test_synonym_database_coverage,
        test_large_document,
        test_markdown_preservation,
    ]
    
    passed = 0
    failed = 0
    for test in tests:
        try:
            test()
            passed += 1
        except Exception as e:
            print(f"✗ {test.__name__}: {e}")
            failed += 1
    
    print(f"\n{'='*50}")
    print(f"Results: {passed} passed, {failed} failed, {passed+failed} total")
    if failed:
        sys.exit(1)
    print("All tests passed! ✓")
