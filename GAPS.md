# GAPS — what changes between this rehearsal and real mainnet day

Everything in `networks/devnet/`, `networks/mainnet/genesis-params.json`,
and `scripts/genesis/` was built and *tested* this session — real binary,
real 4-node devnet, real block production, real remote signing, real
(dummy) gentx rejection — against `base-genesis` as it stood at the time.
**Mid-session, `origin/base-genesis` itself was reset** from a `v1.0.1` pin
to a `v8.4.0` pin (see `git log origin/base-genesis`); this file, and every
script/config in this PR, reflects the post-reset state (`v8.4.0-1-g026e64c8`
at time of writing). This is the honest list of what's still different on
the day it counts for real.

**Re-verification note (2026-08-22, fresh session):** everything below was
re-checked from scratch against the `ark-v0.1.0-alpha` binary rather than
trusted from the prior session. Binary from the Eng 1 tag, gentx fixtures
regenerated and re-run (tampered sig + overclaim still rejected, canonical
hash reproduced), devnet re-deployed with `ark` prefix and `espees`/`aespees`
denom (`make devnet-up` with `DEVNET_BIN` set to the alpha artifact), sentry
isolation re-verified against the *running* network via `net_info`
(validators: exactly 1 peer = own sentry, `pex=false`; new evidence in
`networks/devnet/proof/sentry-isolation.log`), TMKMS remote signing
re-integrated live for validator-0 with the updated `arkvalconspub` key format
(see `remote-signing/proof/live-signing-evidence.log`), block time
re-measured at 1.93-1.99s avg with the same `RoundStepPropose`-contention
root cause (load avg ~7.6 at capture). The `ark-v0.1.0-alpha` tag is now the
real Eng 1 release; the `v1.0.0-rc1` git tag visible in this repo remains
MANTRA's inherited 2024-10-07 upstream tag. Downstream handoff marker at
`networks/devnet/STATUS.md` updated.

## Blocks mainnet genesis outright

- **`ark-v0.1.0-alpha` is now the real Eng 1 release** and is the binary
  this track's devnet was re-verified against. The `v1.0.0-rc1` git tag
  visible in this repo is still MANTRA's inherited 2024-10-07 upstream tag
  and must not be used. Day-1 state-machine decisions taken by Eng 1:
  bech32 prefix `ark`, base denom `aespees` (display `espees`, symbol
  `ESP`), and the `x/sanction`, `x/tax`, and `x/tokenfactory` modules
  stripped. These are now reflected in the devnet templates and fixtures.
- **`networks/mainnet/genesis-params.json` no longer carries `x/tax` or
  `x/tokenfactory` overrides** because those modules were removed by Eng 1.
- **Only rehearsed against 2-4 dummy gentx files.** `collect-gentx.sh`'s
  per-file check boots a throwaway node (~5-8s each) — for a real N-large
  validator cohort this is still fine (a few minutes, one-time, high
  stakes) but hasn't been load-tested at real scale.

## A real, load-bearing codebase bug — resolved by Eng 1

**`app/genesis.go`'s `NewDefaultGenesisState()` was dead and broken** and
was removed by Eng 1 in `ark-v0.1.0-alpha`. `mantrachaind init` uses the
plain SDK basic-module-manager path, so the raw default genesis has
`evm.params.evm_denom: "aatom"`, `mint`/`staking` denom `"stake"`, and an
empty `erc20.token_pairs` list. This repo's `genesis-template.json`
overrides the denom fields directly and does **not** attempt to construct
a native ERC20 token pair (needs a real precompile/contract address from
Eng 1).

## A second discovered requirement: `bank.denom_metadata` is not cosmetic

The EVM module's `InitGenesis` panics at node startup —
`"error initializing evm coin info: denom metadata aespees could not be
found"` — if `app_state.bank.denom_metadata` has no entry for the
bond/mint/evm denom. This isn't caught by `mantrachaind genesis
validate-genesis` (a structural/proto check only) — it only surfaces when
a node actually boots. `genesis-template.json` and `genesis-params.json`
both include a correct `denom_metadata` entry now (`aespees` base,
`espees` display, `ESP` symbol).

## Needs real infrastructure, not just config

- **Sentry topology is config-only on localhost.** `persistent_peers`/
  `pex`/`private_peer_ids` are correctly wired and *tested* (see
  `networks/devnet/README.md`'s sentry section) but all 4 processes share
  one loopback interface — nothing here provides actual network isolation.
  Real infra needs validators on a private subnet with no public IP and
  no inbound route at all, firewalled to accept only from their sentry's
  IP.
- **Every devnet node gets a local `priv_validator_key.json`**, including
  the sentries — a harmless side effect of `pystarport init`'s uniform
  process (sentries are never bonded so it's never used), but not
  representative of real sentry hardware, which shouldn't hold validator
  key material at all.
- **Only 2 bonded validators in the devnet** (by design, to fit "4 nodes"
  while demonstrating real sentry pairing) — losing either one halts the
  chain. Real mainnet needs the actual validator cohort assembled via
  `collect-gentx.sh` (Phase 4, already tested) with enough independent
  bonded validators that losing one still leaves ≥2/3 voting power.

## Remote signing — single-instance today, threshold needed for real mainnet

- **TMKMS softsign, single instance, no HSM.** Key material sits in a
  plain file, protected only by OS file permissions. Real mainnet needs
  either TMKMS with a YubiHSM2/Ledger backend, or a move to threshold
  signing (Horcrux) so no single machine holds a complete usable key. See
  `networks/devnet/remote-signing/README.md`'s comparison table.
- **TCP transport for the remote signer doesn't work as configured** —
  traced to an upstream CometBFT gap (unpersisted ephemeral
  SecretConnection key on every listener restart, confirmed by source:
  `privval/utils.go`'s own `// TODO: persist this key...` comment — still
  present in the `v0.38.23`-family version this repo currently vendors).
  Worked around with a Unix socket, which only works when the signer is
  co-located with the validator on one host. **A genuinely separate-host
  signer setup (the real target for production) needs one of**: a
  CometBFT patch that persists the listener key, a trusted network layer
  that doesn't depend on the ephemeral key for authentication, or
  confirming whether a TMKMS release newer than 0.15.0 (what this session
  installed) has grown a way to tolerate this. Not checked this session.
- **Double-sign protection state** lives on the same disk as everything
  else in this rehearsal. Real mainnet needs this on durable, ideally
  replicated storage — losing it and restarting is exactly the failure
  mode that causes double-signing.

## Lower priority / already mitigated, worth knowing about

- **Observed devnet block time (~1.92s) sits at the upper edge of the
  1-2s target**, not the ~1.1-1.3s the timeout math predicts. Root-caused
  to CPU contention from running 4 full CGO/wasmvm-linked nodes
  concurrently on one shared dev laptop (evidence:
  `networks/devnet/proof/propose-timeout-evidence.log` shows
  `RoundStepPropose` regularly consuming its full 1s timeout). The
  configured values are correct for dedicated hardware — re-run
  `make devnet-verify` on the real target hardware/topology before
  trusting either number as representative.
- **This dev machine had no Go, `pystarport`, or `tmkms` installed at
  all** — all three were installed fresh this session. Two Go-toolchain
  nuances worth knowing: (1) `go.mod` specifies `go 1.25.0`; a newer
  Homebrew `go` (1.27, "latest") builds fine but a transitive dependency
  (`sonic`, a fast-JSON library) prints an environment-compatibility
  warning to **stdout** on every binary invocation outside its tested Go
  range, which broke `pystarport`'s JSON parsing until pinned to
  `go@1.25` specifically. (2) CI's `chain-binary` artifact is a Linux
  x86_64 binary that can't run natively on macOS anyway, so
  `CONTRIBUTING.md`'s "Eng 2-4 don't need Go" guidance doesn't hold here
  without also running inside a Linux container.
- **`pystarport` 0.2.5 (latest on PyPI) needed three independent
  compatibility patches**, all applied automatically and idempotently by
  `networks/devnet/patch-pystarport-cli.py` (fails loudly if pystarport's
  source ever stops matching what it expects): (1) Cosmos SDK v0.50+'s
  `genesis` subcommand nesting, (2) this binary's CLI renaming
  `tendermint show-node-id` to `comet show-node-id` (upstream CometBFT's
  own rename), (3) `interact()`'s default `stderr=subprocess.STDOUT`
  merging the `sonic` warning above into stdout and corrupting every
  `--output json` parse - patched to capture streams separately.
- **`collect-gentx.sh`'s valoper→account address resolution can't use
  `mantrachaind debug addr`** — its output format changed between the
  pre-reset and post-reset binary (from labeled `Bech32 Acc:`/`Bech32
  Val:` lines to raw EVM hex, since this app now uses `ethsecp256k1`
  keys). Replaced with a small self-contained bech32 re-encoder
  (`scripts/genesis/bech32_reencode.py`, standard BIP-173 algorithm, no
  external dependency) rather than depending on CLI output shape that's
  already proven unstable across versions of this same binary.
- **The root `Makefile` has a stale dependency reference**: line ~162
  computes `COSMWASM_VERSION := $(shell go list -m
  github.com/CosmWasm/wasmvm/v2 | sed ...)`, but the post-reset `go.mod`
  is on `github.com/CosmWasm/wasmvm/v3`. `go list -m` for the v2 path
  fails ("not a known dependency"), and since this is a top-level
  `$(shell ...)` assignment, the error prints on **every** `make`
  invocation regardless of target - cosmetic (nothing observed to
  actually break because of it) but noisy, and worth a one-line fix by
  whoever owns the root `Makefile`. Not fixed in this PR — out of this
  track's scope (`networks/`, `scripts/genesis/`) and not
  genesis/consensus related.

- **The CI `validate-genesis` job was broken before this branch touched
  it** (missing `libwasmvm.x86_64.so` on the runner, so it errored before
  ever reaching genesis content) — fixed in `.github/workflows/build.yml`
  as part of this PR.

