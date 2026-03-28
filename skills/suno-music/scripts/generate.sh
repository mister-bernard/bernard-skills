#!/usr/bin/env bash
#
# Suno Music Generation Wrapper
# Simple interface to suno-api.py
#

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="$SCRIPT_DIR/suno-api.py"

# Check if Python script exists
if [[ ! -f "$PYTHON_SCRIPT" ]]; then
    echo "Error: suno-api.py not found at $PYTHON_SCRIPT" >&2
    exit 1
fi

# Check for Python 3
if ! command -v python3 &> /dev/null; then
    echo "Error: python3 not found. Please install Python 3.7+" >&2
    exit 1
fi

# Check for requests library
if ! python3 -c "import requests" 2>/dev/null; then
    echo "Error: Python 'requests' library not installed" >&2
    echo "Install with: pip install requests" >&2
    exit 1
fi

# Check for API key
if [[ -z "${SUNO_API_KEY:-}" ]]; then
    echo "Error: SUNO_API_KEY environment variable not set" >&2
    echo "Set it with: export SUNO_API_KEY='your_key'" >&2
    exit 1
fi

# Run Python script with all arguments
exec python3 "$PYTHON_SCRIPT" "$@"
