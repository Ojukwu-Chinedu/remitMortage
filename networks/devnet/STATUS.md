# Devnet status — handoff marker for Eng 3 (chaos/load) and Eng 4 (explorer/RPC)

**Status: READY for downstream work, with the caveats below.**
Last full re-verification: 2026-08-22 (UTC), on `track/2-consensus-genesis`
@ the commit that updates this file, using the `ark-v0.1.0-alpha` binary.

## What was re-verified end-to-end this session (fresh run, not stale proof)

| Check | Result | Evidence |
|---|---|---|
| 4-node devnet boots reproducibly from `make devnet-up` | PASS | this file's commit; rerun it yourself |
| Block production, avg block time | PASS — 1.94-1.97s (target band 1-2s) | `proof/block-times.log` |
| Sentry isolation live (validators peer ONLY with their sentry, `pex=false`, `private_peer_ids` set) | PASS | `proof/sentry-isolation.log` |
| Both validators signing commits (`block_id_flag: 2`) | PASS | `proof/sentry-isolation.log` |
| TMKMS remote signing for validator-0, live against the running chain | PASS | `remote-signing/proof/live-signing-evidence.log` |
| Gentx validation pipeline (tampered sig + overclaim fixtures rejected, valid accepted) | PASS | `scripts/genesis/rehearsal/transcript.log` |
| Address prefix `ark` and token `KASH` (`esp` base) live in `MsgSend` | PASS | transaction confirmed against the running devnet |

## How to use it

```bash
# 1. Build or copy the Eng 1 binary to build/mantrachaind
make build                 # or copy the ark-v0.1.0-alpha artifact
make devnet-up             # init 4 nodes, wire sentry topology, start
make devnet-verify         # prove block production, refresh proof/block-times.log
make devnet-down           # stop
```

- Chain-id: `arkdevnet_9000-1`
- Bech32 prefix: `ark` (e.g. `ark1...`, `arkvaloper1...`)
- Denom: `KASH` (18-decimal base unit `esp`; `1 KASH = 10^18 esp`)
- Symbol: `KASH`
- RPC endpoints: `127.0.0.1:26657` (sentry-0), `:26667` (validator-0),
  `:26677` (sentry-1), `:26687` (validator-1)
- Eng 4: index against the **sentry** RPCs (26657/26677) — that mirrors the
  real topology, where validator RPC is never public.
- Eng 3: `networks/devnet/README.md` documents topology and account
  allocations; a fixed-mnemonic `community` account and a `faucet` account
  exist for load-test funding (mnemonics in
  `networks/devnet/data/arkdevnet_9000-1/accounts.json` after `devnet-up`).

## What READY does and doesn't mean

- READY = the devnet is reproducible from a clean checkout, produces blocks
  in the 1-2s band, and its topology/signing setup is live-verified, now
  against the real `ark-v0.1.0-alpha` Eng 1 state machine.
- The `make devnet-up` target no longer forces a source build of the current
  branch; it uses the `mantrachaind` binary found at `build/mantrachaind`.
  Set `DEVNET_BIN=/path/to/ark-v0.1.0-alpha` to point at a different release.
- Block-time numbers were measured on a contended dev laptop (load avg ~7.6);
  see `proof/propose-timeout-evidence.log`. Re-measure on real hardware
  before quoting them.

If any of the table's checks fail for you from a clean checkout, that is a
regression — flag it to Eng 2 (Consensus & Genesis Ops).
