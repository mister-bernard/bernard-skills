#!/usr/bin/env bash
# Adversarial Pipeline Orchestrator
# Usage: run-pipeline.sh "TOPIC" [ROUNDS] [OUTPUT_DIR]
#
# This script is a REFERENCE IMPLEMENTATION. In practice, the main-session
# agent orchestrates by spawning sub-agents via sessions_spawn (see SKILL.md).
# This bash version uses the OpenClaw CLI directly for standalone execution.

set -euo pipefail

TOPIC="${1:?Usage: run-pipeline.sh \"TOPIC\" [ROUNDS] [OUTPUT_DIR]}"
ROUNDS="${2:-5}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
SLUG=$(echo "$TOPIC" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-' | head -c 40)
OUTPUT_DIR="${3:-/home/openclaw/.openclaw/workspace/adversarial-runs/${SLUG}-${TIMESTAMP}}"

SKILL_DIR="/home/openclaw/.openclaw/workspace/skills/adversarial-pipeline/scripts"
TRANSCRIPT="${OUTPUT_DIR}/transcript.md"
SYNTHESIS="${OUTPUT_DIR}/synthesis.md"

# Models (override via env)
ADVERSARY_MODEL="${ADVERSARY_MODEL:-anthropic/claude-haiku-3.5}"
RESEARCHER_MODEL="${RESEARCHER_MODEL:-anthropic/claude-sonnet-4}"
STRATEGIST_MODEL="${STRATEGIST_MODEL:-anthropic/claude-opus-4-6}"

echo "=== Adversarial Pipeline ==="
echo "Topic: ${TOPIC}"
echo "Rounds: ${ROUNDS}"
echo "Output: ${OUTPUT_DIR}"
echo "Models: Adversary=${ADVERSARY_MODEL} Researcher=${RESEARCHER_MODEL} Strategist=${STRATEGIST_MODEL}"
echo ""

# Step 1: Initialize
mkdir -p "${OUTPUT_DIR}"
cat > "${TRANSCRIPT}" <<EOF
# Adversarial Debate: ${TOPIC}

**Started:** $(date -u +"%Y-%m-%d %H:%M UTC")
**Rounds:** ${ROUNDS}
**Models:** Adversary=${ADVERSARY_MODEL} | Researcher=${RESEARCHER_MODEL} | Strategist=${STRATEGIST_MODEL}

---

EOF

echo "Transcript initialized: ${TRANSCRIPT}"

# Step 2: Run debate rounds
for round in $(seq 1 "${ROUNDS}"); do
    echo ""
    echo "--- Round ${round}/${ROUNDS} ---"
    
    # Adversary turn
    echo "  Spawning Adversary..."
    ADVERSARY_PROMPT=$(cat "${SKILL_DIR}/adversary-prompt.md")
    ADVERSARY_TASK="You are the Adversary in an adversarial debate pipeline.

Your system prompt:
${ADVERSARY_PROMPT}

Read the transcript so far from: ${TRANSCRIPT}
TOPIC: ${TOPIC}
ROUND: ${round} of ${ROUNDS}

Write your Round ${round} challenge following the format in your system prompt.
Append ONLY your challenge output to the transcript file: ${TRANSCRIPT}
Use shell command: echo '...' >> ${TRANSCRIPT}
Do NOT overwrite the file — APPEND only."

    # In practice, this would be: openclaw sessions spawn --model $ADVERSARY_MODEL --task "$ADVERSARY_TASK" --wait
    # For now, we note this is where the agent spawn happens
    echo "  [Would spawn: ${ADVERSARY_MODEL} with adversary task for round ${round}]"
    
    # Researcher turn
    echo "  Spawning Researcher..."
    RESEARCHER_PROMPT=$(cat "${SKILL_DIR}/researcher-prompt.md")
    RESEARCHER_TASK="You are the Researcher in an adversarial debate pipeline.

Your system prompt:
${RESEARCHER_PROMPT}

Read the transcript so far from: ${TRANSCRIPT}
TOPIC: ${TOPIC}
ROUND: ${round} of ${ROUNDS}

Write your Round ${round} response following the format in your system prompt.
You have access to web_search — use it if you need evidence.
Append ONLY your response to the transcript file: ${TRANSCRIPT}
Use shell command to append. Do NOT overwrite the file."

    echo "  [Would spawn: ${RESEARCHER_MODEL} with researcher task for round ${round}]"
done

# Step 3: Synthesis
echo ""
echo "--- Synthesis Phase ---"
echo "  Spawning Strategist..."
STRATEGIST_PROMPT=$(cat "${SKILL_DIR}/strategist-prompt.md")
STRATEGIST_TASK="You are the Strategist in an adversarial debate pipeline.

Your system prompt:
${STRATEGIST_PROMPT}

Read the full debate transcript from: ${TRANSCRIPT}
TOPIC: ${TOPIC}

Produce your full synthesis following the format in your system prompt.
Write the synthesis to: ${SYNTHESIS}
Also append it to the transcript: ${TRANSCRIPT}"

echo "  [Would spawn: ${STRATEGIST_MODEL} with strategist task]"

echo ""
echo "=== Pipeline Complete ==="
echo "Transcript: ${TRANSCRIPT}"
echo "Synthesis: ${SYNTHESIS}"
