# Devnet status — handoff marker for Eng 3 (chaos/load) and Eng 4 (explorer/RPC)

**Status: READY for downstream work, with the caveats below.**
Last full re-verification: 2026-08-22 (UTC), on `track/2-consensus-genesis`
@ the commit that adds this file, binary built from source at that commit
(`v8.4.0`-lineage `base-genesis`, **no ArkConstellation release tag exists yet**
— see "What READY does and doesn't mean" below).

## What was re-verified end-to-end this session (fresh run, not stale proof)

| Check | Result | Evidence |
|---|---|---|
| 4-node devnet boots reproducibly from `make devnet-up` | PASS | this file's commit; rerun it yourself |
| Block production, avg block time | PASS — 1.93-1.99s (target band 1-2s) | `proof/block-times.log` |
| Sentry isolation live (validators peer ONLY with their sentry, `pex=false`, `private_peer_ids` set) | PASS | `proof/sentry-isolation.log` |
| Both validators signing commits (`block_id_flag: 2`) | PASS | `proof/sentry-isolation.log` |
| TMKMS remote signing for validator-0, live against the running chain | PASS | `remote-signing/proof/live-signing-evidence.log` |
| Gentx validation pipeline (tampered sig + overclaim fixtures rejected, valid accepted) | PASS | `scripts/genesis/rehearsal/transcript.log` |

## How to use it

```bash
make devnet-up       # build binary, init 4 nodes, wire sentry topology, start
make devnet-verify   # prove block production, refresh proof/block-times.log
make devnet-down     # stop
```

- Chain-id: `arkdevnet_9000-1`, denom `amantra` (18 dec, display `mantra`)
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
  in the 1-2s band, and its topology/signing setup is live-verified.
- It does NOT mean chain parameters are final: the binary is built from
  `base-genesis` (upstream `v8.4.0` + baseline commit). **Eng 1 has not yet
  published `v0.1.0-alpha` or an ArkConstellation `v1.0.0-rc1`** (the
  `v1.0.0-rc1` git tag you can see in this repo is MANTRA's inherited 2024
  upstream tag — do not build from it). Denom (`amantra`), module set, and
  chain-id are all still open Day-1 decisions per `CONTRIBUTING.md`; expect
  a re-init (state wipe) when Eng 1's real tag lands.
- Block-time numbers were measured on a contended dev laptop (load avg ~7.6);
  see `proof/propose-timeout-evidence.log`. Re-measure on real hardware
  before quoting them.

If any of the table's checks fail for you from a clean checkout, that is a
regression — flag it to Eng 2 (Consensus & Genesis Ops).
