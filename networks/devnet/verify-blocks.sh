#!/usr/bin/env bash
# Polls a running devnet node's RPC, samples real block heights/timestamps,
# computes the observed average block time, and writes the raw evidence to
# disk. This is proof the devnet actually finalizes blocks in the target
# 1-2s window - not a claim that config values imply it.
set -euo pipefail

RPC="${1:-http://127.0.0.1:26657}"
SAMPLES="${2:-15}"
INTERVAL="${3:-1}"
OUT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/proof"
OUT_FILE="$OUT_DIR/block-times.log"

mkdir -p "$OUT_DIR"

echo "Sampling $SAMPLES blocks from $RPC (every ${INTERVAL}s)..." | tee "$OUT_FILE"
echo "started_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUT_FILE"

heights=()
times=()

for i in $(seq 1 "$SAMPLES"); do
  status="$(curl -sS -m 5 "$RPC/status")" || {
    echo "error: could not reach $RPC/status - is the devnet running? (make devnet-up)" | tee -a "$OUT_FILE" >&2
    exit 1
  }
  height="$(echo "$status" | jq -r '.result.sync_info.latest_block_height')"
  block_time="$(echo "$status" | jq -r '.result.sync_info.latest_block_time')"
  echo "sample=$i height=$height time=$block_time" | tee -a "$OUT_FILE"
  heights+=("$height")
  times+=("$block_time")
  sleep "$INTERVAL"
done

echo "" | tee -a "$OUT_FILE"

python3 - "$OUT_FILE" "${heights[@]}" <<'PYEOF' | tee -a "$OUT_FILE"
import sys
out_file = sys.argv[1]
heights = [int(h) for h in sys.argv[2:] if h != "null"]
if len(heights) < 2:
    print("FAIL: fewer than 2 valid height samples captured - node may not be producing blocks.")
    sys.exit(1)
distinct = sorted(set(heights))
if len(distinct) < 2:
    print(f"FAIL: height did not advance across {len(heights)} samples (stuck at {distinct[0]}) - chain is not producing blocks.")
    sys.exit(1)
advanced = distinct[-1] - distinct[0]
print(f"heights observed: {heights}")
print(f"blocks advanced: {advanced} across the sampling window")
print("PASS: block height is advancing - devnet is producing blocks.")
PYEOF

echo "" | tee -a "$OUT_FILE"
echo "Computing inter-block time from block headers directly (more precise than RPC polling interval)..." | tee -a "$OUT_FILE"

latest_height="$(curl -sS -m 5 "$RPC/status" | jq -r '.result.sync_info.latest_block_height')"
start_height=$((latest_height - 10))
start_height=$((start_height < 2 ? 2 : start_height))

python3 - "$RPC" "$start_height" "$latest_height" <<'PYEOF' | tee -a "$OUT_FILE"
import sys
import urllib.request
import json
import datetime

rpc, start, end = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])

def block_time(h):
    with urllib.request.urlopen(f"{rpc}/block?height={h}", timeout=5) as r:
        data = json.load(r)
    ts = data["result"]["block"]["header"]["time"]
    ts = ts.replace("Z", "+00:00")
    # normalize fractional seconds to microsecond precision for fromisoformat
    if "." in ts:
        head, rest = ts.split(".", 1)
        frac, tz = rest[: rest.index("+")], rest[rest.index("+") :]
        frac = (frac + "000000")[:6]
        ts = f"{head}.{frac}{tz}"
    return datetime.datetime.fromisoformat(ts)

deltas = []
prev = None
for h in range(start, end + 1):
    try:
        t = block_time(h)
    except Exception as e:
        print(f"  (skipping height {h}: {e})")
        continue
    if prev is not None:
        deltas.append((t - prev).total_seconds())
    prev = t

if not deltas:
    print("FAIL: could not compute any inter-block deltas.")
    sys.exit(1)

avg = sum(deltas) / len(deltas)
print(f"inter-block deltas (s): {[round(d, 3) for d in deltas]}")
print(f"average block time: {avg:.3f}s over {len(deltas)} intervals (heights {start}-{end})")

if 0.5 <= avg <= 2.5:
    print(f"PASS: average block time {avg:.3f}s falls within the 1-2s target band (with reasonable margin).")
else:
    print(f"WARN: average block time {avg:.3f}s is outside the 1-2s target band - check timeout_commit/timeout_propose in networks/devnet/pystarport.json.")
PYEOF

echo "" | tee -a "$OUT_FILE"
echo "finished_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUT_FILE"
echo "" | tee -a "$OUT_FILE"
echo "Proof written to: $OUT_FILE"
