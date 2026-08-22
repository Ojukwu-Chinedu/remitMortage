#!/usr/bin/env bash
# collect-gentx.sh — validate a directory of gentx files and compile a
# canonical genesis from the ones that pass, rejecting the rest with a
# specific, attributable reason.
#
# This exists because Cosmos SDK's own `genesis collect-gentxs` deliberately
# does NOT verify gentx signatures ("it cannot verify the signature as it is
# stateless validation" — x/genutil/types/genesis_state.go). It only checks
# message shape and that the self-delegation amount doesn't exceed the
# account's genesis balance. Signature validity is otherwise only ever
# discovered when the real chain boots for the first time and InitChain
# replays every gentx through the ante handler — which, on actual mainnet
# genesis day, is the single worst possible moment to discover a bad
# signature. This script performs that same InitChain replay early, per
# gentx, in an isolated throwaway node, so a bad signature fails loudly
# here instead of during the real boot.
#
# Usage:
#   collect-gentx.sh <gentx-dir> <base-genesis.json> [output-genesis.json]
#
# <base-genesis.json> must already have every prospective validator's
# self-delegation account funded (via `genesis add-genesis-account`) and
# the real target chain-id/params applied — this script does not fabricate
# accounts or parameters, only validates and collects gentxs on top of what
# you give it.
#
# Exit code is non-zero if ANY gentx was rejected, even though the valid
# ones still get compiled — a partial validator set must never be silently
# accepted as final for a real mainnet genesis.
set -euo pipefail

BIN="${MANTRACHAIND_BIN:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/build/mantrachaind}"

GENTX_DIR="${1:?usage: collect-gentx.sh <gentx-dir> <base-genesis.json> [output-genesis.json]}"
BASE_GENESIS="${2:?usage: collect-gentx.sh <gentx-dir> <base-genesis.json> [output-genesis.json]}"
OUTPUT="${3:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/networks/mainnet/genesis-template.json}"

BOOT_TIMEOUT="${COLLECT_GENTX_BOOT_TIMEOUT:-8}"

fail() { echo "error: $*" >&2; exit 1; }

[ -x "$BIN" ] || fail "binary not found or not executable: $BIN (build it with 'make build', or set MANTRACHAIND_BIN)"
[ -d "$GENTX_DIR" ] || fail "gentx directory not found: $GENTX_DIR"
[ -f "$BASE_GENESIS" ] || fail "base genesis not found: $BASE_GENESIS"
command -v jq >/dev/null || fail "jq is required"

CHAIN_ID="$(jq -r '.chain_id' "$BASE_GENESIS")"
[ -n "$CHAIN_ID" ] && [ "$CHAIN_ID" != "null" ] || fail "base genesis has no chain_id: $BASE_GENESIS"

WORK="$(mktemp -d)"
cleanup() {
  local pids
  pids="$(jobs -p)"
  [ -n "$pids" ] && kill $pids 2>/dev/null
  rm -rf "$WORK"
}
trap cleanup EXIT

VALID_DIR="$WORK/valid"
mkdir -p "$VALID_DIR"

# bash 3.2 (macOS's default /bin/bash) has no associative arrays, so
# addr-seen tracking uses a plain "addr file" line log instead of -A.
declare -a ACCEPTED=()
declare -a REJECTED=()
SEEN_LOG="$WORK/seen-addrs.txt"
: > "$SEEN_LOG"

reject() {
  local file="$1" reason="$2"
  REJECTED+=("$file: $reason")
  echo "REJECT  $file"
  echo "        -> $reason"
}

echo "collect-gentx.sh: validating gentxs in $GENTX_DIR against $BASE_GENESIS (chain-id=$CHAIN_ID)"
echo ""

shopt -s nullglob
GENTX_FILES=("$GENTX_DIR"/*.json)
shopt -u nullglob
[ "${#GENTX_FILES[@]}" -gt 0 ] || fail "no *.json files found in $GENTX_DIR"

for f in "${GENTX_FILES[@]}"; do
  name="$(basename "$f")"

  # --- 1. structural checks -------------------------------------------------
  if ! jq empty "$f" >/dev/null 2>&1; then
    reject "$name" "not valid JSON"
    continue
  fi

  msg_count="$(jq '.body.messages | length' "$f" 2>/dev/null || echo 0)"
  if [ "$msg_count" != "1" ]; then
    reject "$name" "expected exactly 1 message, got $msg_count"
    continue
  fi

  msg_type="$(jq -r '.body.messages[0]["@type"]' "$f")"
  if [ "$msg_type" != "/cosmos.staking.v1beta1.MsgCreateValidator" ]; then
    reject "$name" "expected MsgCreateValidator, got $msg_type"
    continue
  fi

  sig_count="$(jq '.signatures | length' "$f" 2>/dev/null || echo 0)"
  if [ "$sig_count" != "1" ]; then
    reject "$name" "expected exactly 1 signature, got $sig_count"
    continue
  fi

  moniker="$(jq -r '.body.messages[0].description.moniker' "$f")"
  val_addr="$(jq -r '.body.messages[0].validator_address' "$f")"
  self_amount="$(jq -r '.body.messages[0].value.amount' "$f")"
  self_denom="$(jq -r '.body.messages[0].value.denom' "$f")"

  if [ -z "$val_addr" ] || [ "$val_addr" = "null" ]; then
    reject "$name" "missing validator_address"
    continue
  fi

  # bech32 valoper -> acc address for balance lookup: same underlying data,
  # different human-readable prefix. `debug addr`'s output format isn't
  # stable across binary versions (this app switched from printing
  # "Bech32 Acc:"/"Bech32 Val:" lines to raw EVM hex when it moved to
  # ethsecp256k1 keys), so this re-encodes bech32 directly instead of
  # depending on that CLI output shape.
  del_addr="$(python3 "$(dirname "${BASH_SOURCE[0]}")/bech32_reencode.py" "$val_addr" ark 2>/dev/null || true)"
  if [ -z "$del_addr" ]; then
    reject "$name" "could not resolve delegator address from validator_address=$val_addr"
    continue
  fi

  prior="$(awk -v a="$del_addr" '$1 == a {print $2; exit}' "$SEEN_LOG")"
  if [ -n "$prior" ]; then
    reject "$name" "duplicate gentx for address $del_addr (already accepted from $prior)"
    continue
  fi

  # --- 2. account-exists + self-delegation-amount pre-check ----------------
  # (collect-gentxs enforces this too - see x/genutil/collect.go - but
  # checking it here first gives a clearly-attributed error before we pay
  # for the much more expensive boot-based signature check below.)
  balance="$(jq -r --arg addr "$del_addr" --arg denom "$self_denom" \
    '.app_state.bank.balances[]? | select(.address == $addr) | .coins[]? | select(.denom == $denom) | .amount' \
    "$BASE_GENESIS")"

  if [ -z "$balance" ]; then
    reject "$name" "account $del_addr not found in base genesis bank balances (denom $self_denom) - add it with 'genesis add-genesis-account' first"
    continue
  fi

  # amounts come straight from an untrusted gentx file, so they're passed
  # as argv (plain data) rather than interpolated into the python source -
  # int() on a non-numeric argv value just raises, it can't execute anything.
  if ! insufficient="$(python3 -c '
import sys
try:
    balance, claimed = int(sys.argv[1]), int(sys.argv[2])
except ValueError:
    print("bad-amount"); sys.exit(0)
print("1" if balance < claimed else "0")
' "$balance" "$self_amount")"; then
    reject "$name" "could not parse amounts (balance=$balance, claimed=$self_amount)"
    continue
  fi
  if [ "$insufficient" = "bad-amount" ]; then
    reject "$name" "non-numeric amount in gentx (balance=$balance, claimed=$self_amount)"
    continue
  fi
  if [ "$insufficient" = "1" ]; then
    reject "$name" "insufficient self-delegation funds: account $del_addr has $balance$self_denom, gentx claims $self_amount$self_denom"
    continue
  fi

  # --- 3. authoritative check: does this gentx actually pass InitChain? ----
  # This is the only place signature validity gets checked - see the header
  # comment for why.
  boot="$WORK/boot-$name"
  mkdir -p "$boot"
  "$BIN" init "$moniker" --chain-id "$CHAIN_ID" --home "$boot" >/dev/null 2>&1
  cp "$BASE_GENESIS" "$boot/config/genesis.json"
  mkdir -p "$boot/config/gentx"
  cp "$f" "$boot/config/gentx/$name"

  if ! "$BIN" genesis collect-gentxs --home "$boot" >"$boot/collect.log" 2>&1; then
    reject "$name" "genesis collect-gentxs failed: $(tail -3 "$boot/collect.log" | tr '\n' ' ')"
    continue
  fi

  boot_log="$boot/start.log"
  "$BIN" start --home "$boot" --minimum-gas-prices "0$self_denom" >"$boot_log" 2>&1 &
  boot_pid=$!
  boot_ok=0
  for _ in $(seq 1 "$BOOT_TIMEOUT"); do
    if ! kill -0 "$boot_pid" 2>/dev/null; then
      break
    fi
    if grep -q '"InitChain"\|initializing blockchain state' "$boot_log" 2>/dev/null && \
       grep -qE 'committed state|indexed block' "$boot_log" 2>/dev/null; then
      boot_ok=1
      break
    fi
    sleep 1
  done
  kill "$boot_pid" 2>/dev/null || true
  wait "$boot_pid" 2>/dev/null || true

  if grep -q "panic: failed to execute DeliverTx" "$boot_log" 2>/dev/null; then
    reason="$(grep -oE "}':.*$" "$boot_log" | tail -1 | sed "s/^}': *//" || true)"
    [ -z "$reason" ] && reason="InitChain panicked replaying this gentx (likely bad signature) - see $boot_log"
    reject "$name" "$reason"
    continue
  fi

  if [ "$boot_ok" -ne 1 ] && ! grep -qE 'committed state|indexed block|InitChain' "$boot_log" 2>/dev/null; then
    reject "$name" "node did not complete InitChain within ${BOOT_TIMEOUT}s - see $boot_log"
    continue
  fi

  echo "$del_addr $name" >> "$SEEN_LOG"
  ACCEPTED+=("$name")
  cp "$f" "$VALID_DIR/$name"
  echo "ACCEPT  $name  (moniker=$moniker, self-delegation=${self_amount}${self_denom})"
done

echo ""
echo "Summary: ${#ACCEPTED[@]} accepted, ${#REJECTED[@]} rejected"

if [ "${#ACCEPTED[@]}" -eq 0 ]; then
  fail "no valid gentx files - nothing to compile"
fi

# --- compile final genesis from only the accepted gentxs -------------------
COMPILE_HOME="$WORK/compile"
mkdir -p "$COMPILE_HOME/config"
cp "$BASE_GENESIS" "$COMPILE_HOME/config/genesis.json"
cp -r "$VALID_DIR" "$COMPILE_HOME/config/gentx"

"$BIN" genesis collect-gentxs --home "$COMPILE_HOME" >/dev/null 2>&1 || fail "final collect-gentxs failed unexpectedly after per-file validation passed"
"$BIN" genesis validate-genesis "$COMPILE_HOME/config/genesis.json" || fail "compiled genesis failed validate-genesis"

mkdir -p "$(dirname "$OUTPUT")"
cp "$COMPILE_HOME/config/genesis.json" "$OUTPUT"
echo ""
echo "Compiled genesis written to: $OUTPUT"
echo "Validators included: ${#ACCEPTED[@]}"

if [ "${#REJECTED[@]}" -gt 0 ]; then
  echo ""
  echo "$((${#REJECTED[@]})) gentx file(s) were rejected and are NOT in the compiled genesis:" >&2
  for r in "${REJECTED[@]}"; do echo "  - $r" >&2; done
  echo "" >&2
  echo "Resolve these with the submitters before treating this genesis as final." >&2
  exit 1
fi
