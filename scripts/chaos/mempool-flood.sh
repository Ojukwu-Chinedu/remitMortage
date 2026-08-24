#!/usr/bin/env bash
# ==============================================================================
# ArkConstellation Mempool Transaction Flood & Base-Fee Benchmark (Track 3 Day 2)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RPC_URL="${1:-${EVM_RPC:-http://127.0.0.1:8545}}"
CHAIN_ID="${CHAIN_ID:-9000}"
TX_COUNT="${TX_COUNT:-200}"
CONCURRENCY="${CONCURRENCY:-20}"

echo "======================================================================"
echo " ArkConstellation Mempool Flood & Fee Market Scaling Benchmark"
echo " RPC URL     : ${RPC_URL}"
echo " Chain ID    : ${CHAIN_ID}"
echo " Tx Count    : ${TX_COUNT}"
echo " Concurrency : ${CONCURRENCY}"
echo "======================================================================"

PYTHON_EXEC="python3"
if ! command -v python3 &>/dev/null; then
    PYTHON_EXEC="python"
fi

export PATH="/Users/ark/Library/Python/3.9/bin:$PATH"

"$PYTHON_EXEC" "${SCRIPT_DIR}/mempool_flood_runner.py" \
    --rpc "${RPC_URL}" \
    --chain-id "${CHAIN_ID}" \
    --txs "${TX_COUNT}" \
    --concurrency "${CONCURRENCY}" \
    "$@"
