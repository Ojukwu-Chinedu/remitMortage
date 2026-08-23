#!/usr/bin/env bash
# ==============================================================================
# ArkConstellation JSON-RPC Automated Test Suite (Track 3 Day 1)
#
# Covers:
# 1. Chain ID & JSON-RPC Connectivity (eth_chainId, net_version)
# 2. Account Queries (eth_getBalance, eth_getTransactionCount)
# 3. Contract Deployment via eth_sendRawTransaction
# 4. Receipt Verification (eth_getTransactionReceipt)
# 5. Contract State Modification (eth_sendRawTransaction)
# 6. Read Query (eth_call)
# 7. Event Log Filtering (eth_getLogs)
# 8. Revert Handling & Error Reporting
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RPC_URL="${1:-${EVM_RPC:-http://127.0.0.1:8545}}"
CHAIN_ID="${CHAIN_ID:-11199}"
PRIVATE_KEY="${PRIVATE_KEY:-0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80}"

echo "======================================================================"
echo " ArkConstellation EVM JSON-RPC Automated Test Suite"
echo " Target RPC   : ${RPC_URL}"
echo " EVM Chain ID : ${CHAIN_ID}"
echo "======================================================================"

PYTHON_EXEC=""
if command -v python3 &>/dev/null; then
    PYTHON_EXEC="python3"
elif command -v python &>/dev/null; then
    PYTHON_EXEC="python"
else
    echo "[-] Error: python3 is required to run the test suite." >&2
    exit 1
fi

export PATH="/Users/ark/Library/Python/3.9/bin:$PATH"

"$PYTHON_EXEC" "${SCRIPT_DIR}/rpc_test_runner.py" \
    --rpc "${RPC_URL}" \
    --chain-id "${CHAIN_ID}" \
    --private-key "${PRIVATE_KEY}" \
    "$@"
