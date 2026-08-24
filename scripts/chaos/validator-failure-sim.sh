#!/usr/bin/env bash
# ==============================================================================
# ArkConstellation Validator Failure & Liveness Simulator (Track 3 Day 2)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RPC_URL="${1:-${CMT_RPC:-http://127.0.0.1:26657}}"
TARGET_POWER="${TARGET_POWER:-33.3}"

echo "======================================================================"
echo " ArkConstellation Validator Fault Tolerance & Liveness Simulation"
echo " CometBFT RPC : ${RPC_URL}"
echo " Fault Power  : ${TARGET_POWER}%"
echo "======================================================================"

PYTHON_EXEC="python3"
if ! command -v python3 &>/dev/null; then
    PYTHON_EXEC="python"
fi

"$PYTHON_EXEC" "${SCRIPT_DIR}/validator_failure_sim.py" \
    --rpc "${RPC_URL}" \
    --target-power "${TARGET_POWER}" \
    "$@"
