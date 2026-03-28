# The Crucible — Quick Start

A multi-agent debate system where an Adversary challenges, a Researcher defends, and a Strategist synthesizes.

## Usage

Tell any OpenClaw agent:

> "Run an adversarial analysis on [TOPIC]"

Or be specific:

> "Run The Crucible: topic='Should we migrate from PostgreSQL to CockroachDB?', rounds=5"

The agent reads `SKILL.md` and orchestrates the debate by spawning sub-agents.

## What You Get

1. **`transcript.md`** — Full debate with all rounds
2. **`synthesis.md`** — Strategist's analysis with:
   - Executive summary
   - Crux identification (key disagreements)
   - Round-by-round scoring
   - Steelman of both sides
   - Risk assessment
   - Recommended actions
   - Bottom line verdict

## Cost

| Config | Rounds | Models | Est. Cost |
|--------|--------|--------|-----------|
| Quick | 3 | Haiku/Haiku/Sonnet | ~$0.10 |
| Standard | 5 | Haiku/Sonnet/Opus | ~$1.00 |
| Deep | 8 | Sonnet/Opus/Opus | ~$3.00 |

## Details

See [SKILL.md](./SKILL.md) for full documentation, orchestration details, and research basis.
