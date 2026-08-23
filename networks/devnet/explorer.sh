#!/usr/bin/env bash
set -euo pipefail

RPC="${1:-http://127.0.0.1:8545}"
INTERVAL="${2:-2}"
LAST=""

echo "EVM explorer watching $RPC (press Ctrl-C to stop)"

while true; do
  BLOCK_HEX=$(curl -sS -m 2 -X POST \
    -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
    "$RPC" 2>/dev/null | jq -r '.result // empty' || true)

  if [ -z "$BLOCK_HEX" ]; then
    sleep "$INTERVAL"
    continue
  fi

  if [ "$BLOCK_HEX" != "$LAST" ]; then
    LAST="$BLOCK_HEX"
    DATA=$(curl -sS -m 2 -X POST \
      -H "Content-Type: application/json" \
      --data "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBlockByNumber\",\"params\":[\"$BLOCK_HEX\",true],\"id\":2}" \
      "$RPC" 2>/dev/null || true)

    if [ -n "$DATA" ]; then
      echo "$DATA" | jq -r '
        "[\(.result.number)] hash=\(.result.hash) time=\(.result.timestamp) txs=\(.result.transactions | length) gasUsed=\(.result.gasUsed) parent=\(.result.parentHash)"
      '
      echo "$DATA" | jq -r '
        .result.transactions[]? |
        "  tx \(.hash) from=\(.from) to=\(.to) value=\(.value) gas=\(.gas) gasPrice=\(.gasPrice)"
      '
    fi
  fi

  sleep "$INTERVAL"
done
