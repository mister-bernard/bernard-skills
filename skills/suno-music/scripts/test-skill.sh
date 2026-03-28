#!/usr/bin/env bash
#
# Test script to verify suno-music skill is properly set up
# Does NOT make actual API calls
#

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "Testing suno-music skill at: $SKILL_DIR"
echo

# Check files exist
echo "✓ Checking file structure..."
files=(
  "SKILL.md"
  "README.md"
  "USAGE_EXAMPLES.md"
  "scripts/generate.sh"
  "scripts/suno-api.py"
)

for file in "${files[@]}"; do
  if [[ -f "$SKILL_DIR/$file" ]]; then
    echo "  ✓ $file"
  else
    echo "  ✗ MISSING: $file"
    exit 1
  fi
done

# Check executables
echo
echo "✓ Checking permissions..."
if [[ -x "$SKILL_DIR/scripts/generate.sh" ]]; then
  echo "  ✓ generate.sh is executable"
else
  echo "  ✗ generate.sh not executable"
  exit 1
fi

if [[ -x "$SKILL_DIR/scripts/suno-api.py" ]]; then
  echo "  ✓ suno-api.py is executable"
else
  echo "  ✗ suno-api.py not executable"
  exit 1
fi

# Check Python syntax
echo
echo "✓ Checking Python syntax..."
if python3 -m py_compile "$SKILL_DIR/scripts/suno-api.py" 2>/dev/null; then
  echo "  ✓ suno-api.py syntax valid"
else
  echo "  ✗ suno-api.py has syntax errors"
  exit 1
fi

# Check bash syntax
echo
echo "✓ Checking Bash syntax..."
if bash -n "$SKILL_DIR/scripts/generate.sh" 2>/dev/null; then
  echo "  ✓ generate.sh syntax valid"
else
  echo "  ✗ generate.sh has syntax errors"
  exit 1
fi

# Check for Python 3
echo
echo "✓ Checking runtime requirements..."
if command -v python3 &> /dev/null; then
  PYTHON_VER=$(python3 --version)
  echo "  ✓ $PYTHON_VER"
else
  echo "  ✗ python3 not found"
  exit 1
fi

# Check for requests library (optional)
if python3 -c "import requests" 2>/dev/null; then
  REQ_VER=$(python3 -c "import requests; print(requests.__version__)")
  echo "  ✓ requests library installed (v$REQ_VER)"
else
  echo "  ⚠ requests library not installed (required for API calls)"
  echo "    Install with: pip install requests"
fi

# Check API key (optional)
echo
echo "✓ Checking configuration..."
if [[ -n "${SUNO_API_KEY:-}" ]]; then
  echo "  ✓ SUNO_API_KEY is set (${#SUNO_API_KEY} chars)"
else
  echo "  ⚠ SUNO_API_KEY not set (required for API calls)"
  echo "    Set with: export SUNO_API_KEY='your_key'"
fi

# Summary
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Skill structure: ✓ VALID"
echo
echo "To use the skill:"
echo "  1. Install requests: pip install requests"
echo "  2. Set API key: export SUNO_API_KEY='your_key'"
echo "  3. Generate music: ./scripts/generate.sh --prompt 'your prompt'"
echo
echo "See SKILL.md and USAGE_EXAMPLES.md for documentation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
