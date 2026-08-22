# Devnet — local 4-node rehearsal network

This is Eng 2's (Consensus & Genesis Ops) local devnet: a 4-node
[pystarport](https://github.com/crypto-org-chain/pystarport) cluster used to
rehearse genesis parameterization, consensus timing, and sentry-node
topology against the actual compiled `mantrachaind` binary before any of it
touches real validators or mainnet.

**Binary target note.** The original task brief for this track assumed a
tagged `v1.0.0-rc1` binary already existed. It doesn't — checked, not
assumed. `origin/base-genesis` was reset mid-session from a `v1.0.1` pin to
a `v8.4.0` pin (see `git log`; `git describe` on the current tip reads
`v8.4.0-1-g026e64c8`), which happens to already carry `cosmos/evm`
integration inherited from that upstream tag. But per `CONTRIBUTING.md`,
`v1.0.0-rc1` is specifically *ArkConstellation's own* "EVM wiring complete"
milestone — no ArkConstellation-specific tag exists yet, and
`CONTRIBUTING.md`'s "Key Decisions" checklist (module keep-or-strip,
chain-id, token allocations, validator identities) is still entirely open.
Everything here targets current `base-genesis` HEAD as it actually compiles
today. See [`GAPS.md`](../../GAPS.md) for the full picture.

---

## Contents

| File | What it is |
|---|---|
| `genesis-template.json` | The reviewable genesis **override patch** — not a full genesis.json (see below) |
| `pystarport.json` | 4-node topology definition (2 validators + 2 sentries), embeds the same override patch |
| `check-genesis-sync.py` | Fails loudly if the two files above drift apart |
| `apply-sentry-topology.py` | Post-`init` pass that wires validator↔sentry-only peering |
| `patch-pystarport-cli.py` | Idempotent compatibility patch, see "Known gaps" below |
| `verify-blocks.sh` | Samples a running devnet and proves block time, writes `proof/` |
| `proof/` | Captured block-time logs from an actual run (committed as evidence) |
| `remote-signing/` | Phase 3 — TMKMS integration for one validator |

## Quickstart

```bash
make devnet-up       # build the binary, init 4 nodes, wire sentry topology, start
make devnet-verify   # sample the running network, prove block time, save proof/
make devnet-down     # stop all node processes
```

`devnet-up` always wipes and regenerates `networks/devnet/data/` from
scratch — there is deliberately no partial-update path, because a genesis
network's whole point is that everyone starts from the same byte-identical
file. If you only want to change something and re-init, edit
`pystarport.json` (and `genesis-template.json` in lockstep — see below) and
re-run `make devnet-up`.

## Why there's no hand-authored full `genesis.json` here

A real chain's `genesis.json` is the union of every registered module's
`DefaultGenesis()` — 31 modules on this app as of this branch (`auth`,
`bank`, `staking`, `slashing`, `mint`, `gov`, `tax`, `tokenfactory`,
`sanction`, `evm`, `erc20`, `feemarket`, `interchainaccounts`, `provider`,
`wasm`, `ibc`, ... — see `app/app.go`), plus account balances, plus
collected `gentx`s. Hand-writing that from scratch invites silent drift the
moment a module changes its schema or a new one gets registered, and it's
exactly the kind of file where "looks plausible" and "is byte-correct" are
not the same thing.

So `genesis-template.json` is **not** the file the binary consumes. It's a
[JSON merge patch](https://www.rfc-editor.org/rfc/rfc7386) — only the
fields Eng 2 actually controls — that gets merged on top of whatever
`mantrachaind init` produces *right now*, from the actual compiled binary,
every time. `pystarport.json` embeds the identical patch under
`arkdevnet_9000-1.genesis` (pystarport's own merge point — see
`init_devnet()` in its `cluster.py`) because pystarport has no
file-include mechanism for plain JSON configs. Since nothing stops those
two copies from drifting, `check-genesis-sync.py` diffs them and fails the
build if they don't match byte-for-byte (minus `genesis-template.json`'s
`_comment` field, which can't legally appear in a real merge patch since
Cosmos SDK's proto-JSON unmarshalling rejects unknown fields).

## Parameter choices and why

All values live in `genesis-template.json` / `pystarport.json`'s `genesis`
key. Denom is `amantra` (18 decimals, display unit `mantra`) — forced by
`app/params/config.go`, not a choice available at the genesis-parameter
level. **This is the codebase's current default, inherited from the
`v8.4.0` baseline — `CONTRIBUTING.md` still lists "native token name,
symbol, and initial allocations" as an open Day-1 decision, so treat
`amantra`/`mantra` as "what the binary does today," not a final answer.**

| Param | Devnet value | Mainnet-shaped or devnet-fast? | Why |
|---|---|---|---|
| `staking.unbonding_time` | `300s` (5 min) | **Devnet-fast** (a real mainnet target of ~8 days is typical for this ecosystem) | Need to actually exercise unbonding/redelegation/slashing-during-unbonding scenarios inside a working session. An 8-day real unbonding period makes that untestable locally. |
| `slashing.signed_blocks_window` | `100` | **Devnet-fast** (mainnet-typical: `1000`) | At ~1-2s/block, a 1000-block window takes ~20-30 min to fill; 100 blocks makes downtime-jailing observable in ~2-3 min. |
| `slashing.slash_fraction_double_sign` | `0.05` | **Real value, kept as-is** | Security-critical economic parameter — rehearsing a fake number here would defeat the point of a rehearsal. |
| `slashing.slash_fraction_downtime` | `0.001` | **Real value, kept as-is** | Same reasoning. |
| `slashing.downtime_jail_duration` | `60s` | Reasonable production value already | No change needed. |
| `mint.*` (inflation, goal_bonded, blocks_per_year) | Conservative, real-shaped economic values | **Real values, kept as-is** | Economic parameters worth rehearsing as plausible production numbers, not placeholders. Note: `blocks_per_year` assumes a target block cadence, not devnet's actual observed one — on this devnet the *wall-clock* inflation accrual will run at a different rate than intended since real blocks land faster/slower than the assumption baked into this constant. Harmless for a local rehearsal; flagged here so nobody mistakes devnet inflation behavior for the mainnet target. |
| `gov.min_deposit` / `expedited_min_deposit` | `1 mantra` / `5 mantra` | **Devnet-fast** (a real mainnet target of tens-of-thousands of tokens is typical) | Need to submit and pass test proposals without needing to pre-fund huge dummy balances. |
| `gov.voting_period` / `expedited_voting_period` | `120s` / `60s` | **Devnet-fast** (mainnet-typical: 2 days / 3 hours) | Need to observe a full submit→vote→pass/reject→execute cycle inside a working session. |
| `gov.quorum` / `threshold` / `veto_threshold` | `0.334` / `0.5` / `0.667` | **Real values, kept as-is** | These define governance safety properties — worth rehearsing as real. |
| `consensus.params.block.{max_bytes,max_gas}` | `1000000` / `75000000` | Reasonable production values | Reused as-is; these aren't iteration-speed-sensitive. |
| `consensus.params.evidence.max_bytes` | `1000000` | Must be ≤ `block.max_bytes` | The SDK's raw default (`1048576`) is *larger* than the block size chosen above and fails genesis validation once block size is shrunk to match; this bit us during rehearsal (see git history) and is exactly the kind of drift-from-defaults trap this file exists to catch. |
| `consensus.params.abci.vote_extensions_enable_height` | `0` (disabled) | Deliberately left off | No oracle/price-feed module is registered in this app (`app_state` has no `oracle`/`marketmap` key as of this branch), so there's nothing that would use vote extensions today; leaving this at the binary's own default avoids inventing a value for a feature nothing consumes yet. |
| `staking.bond_denom`, `mint.mint_denom`, `evm.params.evm_denom`, `evm.params.extended_denom_options.extended_denom` | `amantra` | **Required, not optional** | `mantrachaind init`'s raw default has these as the generic SDK placeholders `stake`/`aatom` — see "Known gaps" below for why `app/genesis.go`'s own attempt to fix this doesn't actually run. Without this override the chain is internally inconsistent (funded accounts hold `amantra`, staking module expects `stake`). |
| `x/tax.mca_address`, `x/tokenfactory.fee_collector_address` | A dedicated devnet-only test address (`mantra14mmu4gfznp8drpdp304tq9kfx88wuxpf0uqjua`, known mnemonic in `pystarport.json`'s `accounts[].community`) | **Devnet placeholder** | `x/tax`'s own Go-code default genesis hardcodes a *real* MANTRA mainnet address for `mca_address` (`x/tax/types/params.go`). `x/tax` is explicitly listed as an open "keep or strip?" decision in `CONTRIBUTING.md` — shipping a real mainnet address into a devnet rehearsal file risked exactly the kind of copy-paste-into-the-real-thing mistake this pipeline is supposed to prevent. |

Everything not listed above (bank, auth, IBC, wasm, erc20, feemarket's EVM
base-fee mechanics, etc.) is left at the binary's own compiled-in default —
no override, on purpose, so this file's diff only shows what Eng 2 actually
decided. `feemarket.params.base_fee`'s raw default is `10^9` atto-units,
which only *looks* like a huge number as a bare integer — at 18 decimals
that's roughly a "1 gwei" analog, a completely normal EVM gas price, not
something that needs fixing.

## Account allocations

Set in `pystarport.json`'s `validators[]`/`accounts[]`, all funded from
nothing (no external faucet, no real funds) — this is a from-scratch local
genesis. Amounts below are in whole `mantra` (18 decimals, so e.g. 100,000
mantra = `100000` followed by eighteen zeros = `100000000000000000000000`
`amantra` in the actual config):

- `validator-0`, `validator-1`: 100,000 mantra each, self-delegate 50,000 mantra each (bonded)
- `sentry-0`, `sentry-1`: 10,000 mantra each (never bonded — see topology below)
- `community` (devnet-only, fixed mnemonic — see table above): 500,000 mantra
- `faucet`: 1,000,000 mantra, for later manual transaction testing
- `alice`, `bob`: 1,000 mantra each, generic test users

All mnemonics except `community`'s are freshly auto-generated by pystarport
on every `devnet-up` and written to `data/arkdevnet_9000-1/accounts.json`
(gitignored — see below) — never committed, never reused across runs.
`community` uses a fixed, publicly-known devnet-only mnemonic so the
`x/tax`/`x/tokenfactory` addresses above stay stable across regenerations
instead of needing runtime placeholder substitution. **This mnemonic must
never be reused for anything beyond this local devnet.**

## Sentry node architecture (simulated locally)

4 nodes, 2 validator/sentry pairs:

```
        [sentry-0]────────[sentry-1]         "public" relay tier
       /  (node0)          (node1)  \          — the only nodes with pex=true
      persistent_peers +            persistent_peers +
      private_peer_ids               private_peer_ids
      (hides validator's IP)         (hides validator's IP)
      /                                          \
[validator-0]                              [validator-1]
   (node1)                                    (node3)
persistent_peers = sentry ONLY               same
pex = false                                  pex = false
```

Wiring is applied by `apply-sentry-topology.py`, run automatically between
`pystarport init` and `pystarport start`. This has to be a separate pass
because pystarport only knows how to build one uniform full-mesh
`persistent_peers` string across every node — it has no per-role topology
concept — and because real p2p node IDs only exist *after* `init` has
generated each node's `node_key.json`, so they can't be hardcoded into
`pystarport.json` ahead of time.

Concretely, for each validator/sentry pair:

- **Validator** (`node1`, `node3`): `persistent_peers` = its sentry only.
  `pex = false` — it will never learn about or dial any other peer, by any
  mechanism, even accidentally.
- **Sentry** (`node0`, `node2`): `persistent_peers` = its validator + the
  other sentry (so blocks/votes still relay across the public tier).
  `private_peer_ids` = its validator's node ID, so the validator's address
  is never included in PEX gossip to the rest of the network.
  `unconditional_peer_ids` = its validator's node ID, so the validator
  connection is never dropped under peer-limit churn.

### What's simulated vs. what changes on real infra

| Here (localhost) | On real infra |
|---|---|
| "Isolation" = `persistent_peers`/`pex`/`private_peer_ids` config only, all 4 processes reachable on `127.0.0.1` | Actual network isolation: validators on a private subnet/VPC with **no public IP and no inbound route from the internet at all**; only the sentry's p2p port is internet-facing |
| Nothing stops another local process from port-scanning `127.0.0.1:26650` and connecting to the validator directly | Firewall/security-group rules physically block any inbound connection to the validator's p2p port except from its designated sentry IP(s) |
| One sentry per validator, no redundancy | Production typically runs ≥2 sentries per validator across separate hosts/AZs for redundancy |
| Both validators equal-weight, only 2 bonded — losing either one halts the chain (no 2/3 without both) | Real validator cohort (Phase 4) needs enough independent bonded validators that losing any one still leaves ≥2/3 voting power online |
| `priv_validator_key.json` generated locally by `mantrachaind init` on the validator node itself | Phase 3 — should be a remote signer (this rehearsal integrates single-instance TMKMS; see `remote-signing/`), not a key file sitting on the validator's own disk |

## Consensus timing — target 1-2s finality

CometBFT's block interval, for a healthy round with no failed votes, is
dominated by one deliberately-always-paid cost plus the actual
propose/prevote/precommit round trip:

```
block_time ≈ timeout_commit + (propose + prevote + precommit round trip)
```

`timeout_commit` is **always** paid in full — CometBFT deliberately pauses
this long after every commit before starting the next round, to give the
network time to fully gossip the block. `timeout_propose`/`timeout_prevote`/
`timeout_precommit` are *upper bounds* on each step, not a mandatory wait —
under normal conditions each step completes as soon as ≥2/3 voting power
has voted, which on a healthy network is tens of milliseconds, not the full
timeout.

Configured in `pystarport.json`'s `config.consensus` block:

```
timeout_propose   = 1s      (down from CometBFT's ~3s default)
timeout_prevote    = 1s
timeout_precommit = 1s
timeout_commit     = 1s      (pystarport's own baseline default, made explicit)
```

**Predicted:** `timeout_commit(1s)` + a round trip of tens-to-low-hundreds
of milliseconds on localhost ≈ **~1.1-1.3s per block**.

**Observed** (`proof/block-times.log`, captured from a live 4-node run — see
that file for the exact numbers from this branch's verification run): in
the same ballpark, at the upper edge of the 1-2s target rather than the
middle of the predicted range.

### Why the gap — investigated, not hand-waved

`proof/propose-timeout-evidence.log` captures the actual cause: on a
meaningful fraction of blocks, `RoundStepPropose` fully consumes its
1-second timeout (`Timed out dur=1000 ... step=RoundStepPropose`) rather
than completing in tens of milliseconds. This means the proposing
validator isn't finishing block creation within the 1s window — most
likely because this is 4 full CGO/wasmvm-linked Cosmos SDK node processes
running concurrently on a single shared development laptop, not dedicated
hardware (see the proof file for the captured system load average at
sample time).

**This is a localhost-contention artifact, not a config problem.** The
configured values (`timeout_propose=1s`, `timeout_commit=1s`) are the
correct target for real, non-contended validator hardware. Flagged in
`GAPS.md`: re-run `verify-blocks.sh` against the real target
hardware/topology before trusting these numbers as representative of
mainnet block time.

### Reproducing the proof yourself

```bash
make devnet-up
make devnet-verify   # overwrites networks/devnet/proof/block-times.log
```

## Regenerating everything from scratch

```bash
# 1. Edit networks/devnet/genesis-template.json AND pystarport.json's
#    "genesis" key together (see check-genesis-sync.py).
# 2. Edit networks/devnet/pystarport.json for topology/account changes.
make devnet-up
```

Under the hood (`scripts/makefiles/devnet.mk`):

1. `make build` — compiles `mantrachaind` from source (native, not the CI
   artifact — see "Known gaps" below for why).
2. `devnet-venv` — creates `.venv-pystarport` (Python **3.9**, not whatever
   `python3` defaults to — see "Known gaps"), installs `pystarport`, and
   applies `patch-pystarport-cli.py`.
3. `devnet-check-genesis-sync` — refuses to continue if the two genesis
   patch copies disagree.
4. `pystarport init` — generates all 4 node homes, funds accounts, submits
   the 2 validator gentxs, collects them, merges the genesis patch.
5. `apply-sentry-topology.py` — rewrites `config.toml` p2p settings per node.
6. `pystarport start` — launches all 4 node processes under `supervisord`.

## Known gaps / non-obvious things a future operator needs to know

- **`app/genesis.go`'s `NewDefaultGenesisState()` is never actually
  called anywhere in `cmd/`** — verified by grepping the whole tree for
  its name; only its own definition matches. It looks like it's meant to
  wire `evm.params.evm_denom`, a native `erc20` token pair, and the EVM
  feemarket's base fee to `amantra`, but `mantrachaind init` goes through
  the plain SDK basic-module-manager path instead, so none of that
  actually happens — the raw default genesis has `evm_denom: "aatom"` and
  an *empty* `erc20.token_pairs` list. Worse: if this function *were*
  wired in, `erc20State.TokenPairs[0].Denom = FeeDenom` would panic on
  index 0 of an empty slice, since `erc20types.DefaultGenesisState()`
  always returns `TokenPairs: []TokenPair{}` (verified in the vendored
  `cosmos/evm` fork's `x/erc20/types/genesis.go`). This repo's
  `genesis-template.json` fixes the denom fields directly rather than
  relying on that function; it does **not** attempt to construct a native
  ERC20 token pair (needs a real precompile/contract address, which is
  Eng 1's `app`/`x` domain to wire correctly, not something to improvise
  a value for here — see `GAPS.md`).
- **This machine's Homebrew-installed Go (1.27, latest) is newer than a
  transitive dependency expects**, and that matters here specifically:
  a `sonic/ast` JSON library (pulled in transitively) prints a
  compatibility warning *to stdout* on every invocation when the Go
  toolchain is outside its tested range (`go1.17~1.26`). That warning
  text breaks pystarport's `json.loads()` calls on `mantrachaind keys add
  --output json`, since the output is no longer valid JSON on its own.
  Fixed by building with `go@1.25` (via `brew install go@1.25`, keg-only,
  used via its full `/opt/homebrew/opt/go@1.25/bin` path) instead of the
  default `go` formula — which also happens to be the exact version
  `go.mod` specifies (`go 1.25.0`), so this is the more correct choice
  independent of the warning. If `make build` ever fails downstream tools
  with unparseable-JSON errors again, check `go version` first.
- **pystarport 0.2.5 (latest on PyPI) predates Cosmos SDK v0.50's `genesis`
  subcommand nesting.** It calls `add-genesis-account`/`gentx`/
  `collect-gentxs`/`validate-genesis` as root-level commands; this repo's
  SDK only registers them under `mantrachaind genesis <cmd>`.
  `patch-pystarport-cli.py` patches the installed package idempotently
  (and fails loudly, not silently, if pystarport's source no longer
  matches what it expects to replace). Runs automatically via
  `make devnet-venv`. If pystarport ever ships a fix upstream, this patch
  becomes a harmless no-op the moment the old strings disappear from its
  source — the failure mode is loud, not silent breakage.
- **pystarport requires Python ≤3.11** (it pins `PyYAML<6.0.0`, which
  fails to build from source under Python 3.12's Cython toolchain changes
  and has no prebuilt wheel for 3.12 at that pin). `devnet-venv` uses
  `python3.9` explicitly rather than whatever `python3` resolves to.
- **This machine had no `go` toolchain installed at all originally** and
  CI's `chain-binary` artifact is a Linux x86_64 binary that can't run
  natively on macOS anyway — so this rehearsal builds `mantrachaind` from
  source locally rather than following `CONTRIBUTING.md`'s "Engineers 2-4
  don't need Go, pull the CI artifact" guidance. That guidance is correct
  for a Linux dev/CI environment; it doesn't hold on macOS without also
  running the binary inside a Linux container. Noted here so the next
  person doesn't assume the CI artifact is directly usable for a local
  pystarport run on a Mac.
- **The CI `validate-genesis` job was broken before this branch touched
  it** (missing `libwasmvm.x86_64.so` on the runner — see
  `.github/workflows/build.yml`, fixed in this PR). Not fixing it would
  have meant every genesis file this track adds gets silently skipped by
  CI's only genesis-correctness check, for a reason unrelated to the
  genesis file's actual content.
- **A true production sentry doesn't have a `priv_validator_key.json` at
  all** (or at minimum, it's never the one CometBFT actually signs with).
  Every pystarport-managed node gets one generated by `mantrachaind init`
  uniformly, including the sentries — harmless here since it's never
  bonded, but not representative of the real target architecture. Phase 3
  addresses this for the validator side (remote signing); see
  `remote-signing/README.md`.
- `data/` (all generated node homes, keys, logs, the live genesis.json) is
  gitignored — regenerate with `make devnet-up`, never hand-edit or commit
  it. `proof/` is **not** gitignored — those logs are the evidence this
  phase actually worked, not disposable output.
