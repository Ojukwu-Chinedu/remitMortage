#!/usr/bin/env bash
# hash-genesis.sh — compute and print the canonical SHA-256 of a genesis
# file, in the exact format validators need to verify against.
#
# "Canonical" matters here: a genesis.json re-serialized by different tools
# (or even the same tool on different platforms/locales) can reorder map
# keys or vary whitespace without changing meaning, which silently changes
# the raw-byte SHA-256 even though the genesis is identical. This script
# hashes two things and labels them separately so nobody accidentally
# compares a canonicalized hash against a raw-bytes hash and gets a false
# mismatch (or worse, a false match):
#
#   1. raw bytes  - sha256sum of the file exactly as it sits on disk. This
#      is what you get from `sha256sum genesis.json` / `shasum -a 256`, and
#      what most validators will actually run. It is fragile to whitespace/
#      key-order differences between how different tools wrote the file.
#   2. canonical  - sha256 of the file after `jq -S -c .` (sorted keys,
#      compact, no incidental whitespace). This is the one that should
#      match across everyone's copy of the genesis regardless of which
#      editor or script last touched formatting - use THIS as the value
#      validators publish and cross-check with each other.
#
# Usage:
#   hash-genesis.sh <genesis.json>
set -euo pipefail

GENESIS="${1:?usage: hash-genesis.sh <genesis.json>}"

fail() { echo "error: $*" >&2; exit 1; }

[ -f "$GENESIS" ] || fail "file not found: $GENESIS"
command -v jq >/dev/null || fail "jq is required"

if ! jq empty "$GENESIS" >/dev/null 2>&1; then
  fail "$GENESIS is not valid JSON"
fi

sha256() {
  if command -v sha256sum >/dev/null; then
    sha256sum | awk '{print $1}'
  else
    shasum -a 256 | awk '{print $1}'
  fi
}

RAW_HASH="$(sha256 < "$GENESIS")"
CANONICAL_HASH="$(jq -S -c . "$GENESIS" | sha256)"

CHAIN_ID="$(jq -r '.chain_id // "unknown"' "$GENESIS")"
GENESIS_TIME="$(jq -r '.genesis_time // "unknown"' "$GENESIS")"

echo "file:             $GENESIS"
echo "chain_id:         $CHAIN_ID"
echo "genesis_time:     $GENESIS_TIME"
echo ""
echo "raw bytes sha256:       $RAW_HASH"
echo "  (what 'shasum -a 256 $GENESIS' gives you - fragile to formatting)"
echo ""
echo "canonical sha256:       $CANONICAL_HASH"
echo "  (jq -S -c . | sha256 - THIS is the value to publish and cross-check)"
