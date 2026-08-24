#!/usr/bin/env bash
# ==============================================================================
# ArkConstellation Validator Fault Tolerance & Liveness Test (Track 3 Day 2)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="${CUSTOM_BIN_DIR:-}${CUSTOM_BIN_DIR:+:}$HOME/Library/Python/3.9/bin:$HOME/.local/bin:$HOME/go/bin:$HOME/.solc-bin:$PATH"

PYTHON_EXEC="python3"
if ! command -v python3 &>/dev/null; then
    if command -v python &>/dev/null; then
        PYTHON_EXEC="python"
    else
        echo "[-] Error: python3 is required to run the test suite." >&2
        exit 1
    fi
fi

exec "$PYTHON_EXEC" "${SCRIPT_DIR}/validator_failure_sim.py" "$@"
