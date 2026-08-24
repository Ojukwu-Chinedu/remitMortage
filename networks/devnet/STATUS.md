# Devnet status — handoff marker for Eng 3 (chaos/load) and Eng 4 (explorer/RPC)

**Status: READY for downstream work, with the caveats below** (one WARN, not
a failure — see the block-time row).
Last full re-verification: 2026-08-23 (UTC), on `track/2-add-devnet-info`
after merging `origin/base-genesis` (which brought in `track/1-state-machine`
and `docs/decisions/module-and-config-decisions.md`), rebuilding the binary
from that merged code, and reconciling every genesis parameter in this track
against that doc's locked decisions. Chain-id/bech32-prefix/denom are
unchanged from the previous marker; unbonding period, voting period,
slashing fractions, `max_validators`, and `timeout_commit` were corrected to
match the now-locked values (see `GAPS.md`'s reconciliation note for specifics).

## What was re-verified end-to-end this session (fresh run, not stale proof)

| Check | Result | Evidence |
|---|---|---|
| 4-node devnet boots reproducibly from `make devnet-up`, against the freshly rebuilt binary | PASS | this file's commit; rerun it yourself |
| Block production, avg block time | **WARN** — 2.97s avg, above the 1-2s target band (was 1.94-1.97s before `timeout_commit` was corrected `1s`→`2s` per decision #12) | `proof/block-times.log`; root-cause discussion in `GAPS.md` |
| Sentry isolation live (validators peer ONLY with their sentry - exactly 1 peer each, `pex=false`, both validators bonded and signing) | PASS | `proof/sentry-isolation.log` |
| TMKMS remote signing for validator-0, live against the running chain, local key removed (no fallback possible) | PASS | `remote-signing/proof/live-signing-evidence.log` |
| Gentx validation pipeline (tampered sig + overclaim fixtures rejected, valid accepted, exit code 1 confirmed non-tee'd) | PASS | `scripts/genesis/rehearsal/transcript.log` |
| `collect-gentx.sh`'s account-prefix derivation (fixed this session - was hardcoded to `"ark"`, now derived from the base genesis) | PASS | same transcript; also round-trip tested standalone, see `GAPS.md` |
| `check-genesis-sync.py` (genesis-template.json / pystarport.json drift check) | PASS | ran directly, exits 0 |
| `make devnet-info` / `make devnet-log` / `make devnet-explore` targets and `networks/devnet/explorer.sh` | PASS | PR review fixes applied; `make devnet-explore` prints live EVM blocks |
| `collect-gentx.sh` + `hash-genesis.sh` re-run on current fixtures | PASS | 2/2 valid accepted, 2/2 bad rejected; canonical SHA-256 reproduced: `d0e283f6...96316d61` |

The block-time WARN is real and not swept under the rug: `timeout_commit`
was raised from `1s` to the decision-#12-locked `2s`, and the other three
CometBFT round timeouts (`timeout_propose`/`timeout_prevote`/
`timeout_precommit`, still `1s` each) appear to be adding real overhead on
top of it. Not tuned further this session per decision #12's own "do not
chase sub-second block times" guidance — flagged for whoever picks this up
next, with a specific suggestion (shrink the other three timeouts, not
`timeout_commit`) in `GAPS.md`.

## How to use it

```bash
# 1. Build or copy the Eng 1 binary to build/mantrachaind
make build                 # or copy the ark-v0.1.0-alpha artifact
make devnet-up             # init 4 nodes, wire sentry topology, start
make devnet-verify         # prove block production, refresh proof/block-times.log
make devnet-down           # stop
```

- Chain-id: `arkdevnet_9000-1` (EVM chain-id `9000`, auto-derived by `app/config.go`'s `EVMChainIDMap`)
- Bech32 prefix: `ark` (e.g. `ark1...`, `arkvaloper1...`)
- Denom: `KASH` display (18 dec.) / `espees` intermediate (9 dec., gas-price display only) / `esp` base (0 dec.); `1 KASH = 10^18 esp = 10^9 espees`
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

- READY = the devnet is reproducible from a clean checkout, its
  topology/signing/gentx pipeline is live-verified against the current
  merged state machine, and the one open item (block time) is a measured,
  understood WARN, not an unknown.
- The `make devnet-up` target no longer forces a source build of the current
  branch; it uses the `mantrachaind` binary found at `build/mantrachaind`.
  Set `DEVNET_BIN=/path/to/a/release` to point at a different binary.
- Block-time numbers were measured on a shared dev laptop; re-measure on real
  before quoting them.

If any of the table's checks fail for you from a clean checkout, that is a
regression — flag it to Eng 2 (Consensus & Genesis Ops).
