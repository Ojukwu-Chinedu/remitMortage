# Genesis assembly tooling

Two scripts, meant to run once, for real, under time pressure, on mainnet
genesis day. Both fail loudly and specifically on bad input rather than
silently proceeding — see the header comment in each for the reasoning.

## `collect-gentx.sh`

```
collect-gentx.sh <gentx-dir> <base-genesis.json> [output-genesis.json]
```

Validates every `*.json` in `<gentx-dir>` and compiles the ones that pass
into a genesis file (default output: `networks/mainnet/genesis-template.json`).
`<base-genesis.json>` must already have every prospective validator's
self-delegation account funded and the real chain params applied — this
script validates and collects, it does not fabricate accounts or params.

Checks, per gentx:

1. **Structural** — valid JSON, exactly one `MsgCreateValidator` message,
   exactly one signature, no duplicate submissions for the same address.
2. **Account exists / self-delegation amount** — the delegator address has
   a balance in the base genesis, and it's ≥ the claimed self-delegation.
3. **Signature** — genuinely verified by replaying the gentx through a real
   `InitChain` in an isolated throwaway node. This is deliberate, not
   incidental: Cosmos SDK's own `genesis collect-gentxs` explicitly does
   *not* verify signatures ("it cannot verify the signature as it is
   stateless validation" — `x/genutil/types/genesis_state.go`), so without
   this step a bad signature would only surface when the real chain boots
   for the first time — the single worst possible moment to find out.

A gentx that fails any check is rejected with the specific reason and
excluded from the compiled output; the rest still get compiled. The
script's exit code is non-zero if *anything* was rejected, even though the
valid ones were still compiled — a partial validator set must never look
like a clean success. See `rehearsal/` for a worked example against 4 dummy
gentxs (2 valid, 2 deliberately broken).

## `hash-genesis.sh`

```
hash-genesis.sh <genesis.json>
```

Prints two SHA-256 hashes, labeled: the raw-bytes hash (what
`shasum -a 256` gives you, fragile to whitespace/key-order differences
between tools) and the canonical hash (`jq -S -c .` first — sorted keys,
no incidental formatting). Publish and cross-check the **canonical** one;
it's the value that stays identical regardless of which editor or script
last touched the file's formatting.

## Testing

```bash
./scripts/genesis/collect-gentx.sh \
  scripts/genesis/rehearsal/gentx \
  scripts/genesis/rehearsal/base-genesis.json \
  /tmp/out.json
./scripts/genesis/hash-genesis.sh /tmp/out.json
```

See `rehearsal/README.md` and `rehearsal/transcript.log` for the captured,
already-run result.
