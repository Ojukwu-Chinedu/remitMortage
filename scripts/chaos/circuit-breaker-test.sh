#!/usr/bin/env bash
# ==============================================================================
# ArkConstellation Protocol-Level Circuit Breaker Test (Track 3 Day 2)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CMT_RPC="${1:-${CMT_RPC:-http://127.0.0.1:26657}}"
EVM_RPC="${2:-${EVM_RPC:-http://127.0.0.1:8545}}"
CHAIN_ID="${CHAIN_ID:-arkdevnet_9000-1}"

echo "======================================================================"
echo " ArkConstellation Protocol Circuit Breaker Test Suite"
echo " CometBFT RPC : ${CMT_RPC}"
echo " EVM JSON-RPC : ${EVM_RPC}"
echo " Chain ID     : ${CHAIN_ID}"
echo "======================================================================"

PYTHON_EXEC="python3"
if ! command -v python3 &>/dev/null; then
    PYTHON_EXEC="python"
fi

"$PYTHON_EXEC" "${SCRIPT_DIR}/circuit_breaker_test.py" \
    --cmt-rpc "${CMT_RPC}" \
    --evm-rpc "${EVM_RPC}" \
    --chain-id "${CHAIN_ID}" \
    "$@"
