# Eng 1 (State Machine) — Status

**Branch:** `track/1-state-machine`, cut from `main` (not `base-genesis` — see "Branch note" below).
**Tag naming:** `ark-v0.1.0-alpha`, `ark-v1.0.0-rc1`, `ark-v1.0.0` — deliberately **not** bare `v*`, since this fork inherited ~90 upstream MANTRA tags and `v1.0.0-rc1` already exists, pointing at MANTRA history from 2024-10-07 (`git tag -l` / `git log -1 v1.0.0-rc1` confirms this — do not check that tag out expecting anything Ark-specific).

## Branch note

The task brief for this track says "off current main." `CONTRIBUTING.md` (as it stood pre-reset) says track branches should cut from `base-genesis` and PRs should target `base-genesis`. At time of writing, `base-genesis` = `main` + exactly one commit (`026e64c8`, "chore: initialize ArkConstellation baseline from v8.4.0..." — pure docs/scaffolding, confirmed via `git diff origin/main origin/base-genesis` touches no `app/`/`cmd/`/`x/` files), so this is a real but low-stakes discrepancy — flagging it rather than silently picking one. This branch's diff is base-genesis-compatible; retarget the PR base if that's actually what's wanted.

## Day 1

### Ground truth (confirmed independently, not assumed)

- `origin/main` HEAD: `3698b48b` ("feat: change dukong v8.4.0 upgrade height (#683)")
- `origin/base-genesis` HEAD: `026e64c8`
- No Ark-specific tags exist (`git tag -l` has zero `ark-*` matches).
- `v1.0.0-rc1` exists and is MANTRA's own 2024-10-07 upstream tag — confirmed via `git log -1 --format="%H %ai %s" v1.0.0-rc1`, not assumed from the task brief.

### Two flagged bugs — one confirmed and fixed, one did not reproduce

1. **`app/genesis.go`'s `NewDefaultGenesisState()` was dead code — confirmed independently** (grepped the whole tree for call sites; only its own definition matched). Worse than dead: it would have panicked if ever wired in (`erc20State.TokenPairs[0].Denom = ...` on index 0 of what `erc20types.DefaultGenesisState()` always returns as an empty slice — verified in the vendored fork's `x/erc20/types/genesis.go`). **Decision: removed, not wired in.** Genesis-time denom/erc20/`bank.denom_metadata` customization is the deployment-time genesis-merge-patch process's job (documented in `networks/devnet/README.md` / `networks/mainnet/RUNBOOK.md` from the genesis-ops track), not something to hardcode into the binary's `init` path — that's both safer (reviewable, tested) and matches how `mantrachaind init` actually produces genesis today (plain SDK basic-module-manager defaults; confirmed via `cmd/mantrachaind/cmd/commands.go`'s `genutilcli.InitCmd` wiring — it does **not** go through `NewDefaultGenesisState` or even `(app *App).DefaultGenesis()`, which is test-only code, used exclusively by `app/test_helpers.go` and `tests/e2e/chain.go`).
2. **Root `Makefile:162` `wasmvm/v2` vs `go.mod`'s `v3` — did NOT reproduce.** Checked directly: `git diff origin/main origin/base-genesis -- Makefile` is empty, and the Makefile on both currently reads `github.com/CosmWasm/wasmvm/v3` correctly (line ~181, not 162 — line numbers had shifted). This may have reflected a transient/stale local state during a prior session's mid-flight branch juggling, or been fixed upstream since. Reporting this plainly rather than "fixing" something that isn't currently broken.
3. **Hardcoded MANTRA mainnet address in `x/tax`, confirmed eliminated by removal — plus a second copy found and removed.** `x/tax/types/params.go`'s `DefaultMcaAddress = "mantra15m77x4pe6w9vtpuqm22qxu0ds7vn4ehzwx8pls"` is gone with the rest of `x/tax` (see below). **A second, independent instance of MANTRA-specific address-blacklisting was found while removing `x/sanction`**: the real v8.4.0 upgrade handler (`app/upgrades/v8_4/upgrades.go`) blacklisted a specific MANTRA mainnet address (`mantra13n9sk3p8x7tpq9adgxvzv9q0qev953mld0hwva`) via `SanctionKeeper.AddToBlacklist` as part of MANTRA's own real production incident response — removed along with the `SanctionKeeper` dependency it required.

### Module stripping — `x/sanction`, `x/tax`, `x/tokenfactory`

All three fully removed: imports, `maccPerms` entries, keeper struct fields, store keys, keeper construction, IBC-transfer-stack middleware wrap (`tokenfactory.NewIBCModule`), module-manager registration, all four ordering lists (`BeginBlockers`/`EndBlockers`/`InitGenesis`/`ExportGenesis`), the `x/sanction`-derived ante decorators on **both** the Cosmos and EVM ante handlers (`app/ante/cosmos.go`, `app/ante/evm.go` — this was real execution-path wiring, not just a registered module), the wasm capability flag advertising `"tokenfactory"` support (`app/wasm.go` — would otherwise falsely advertise a capability to contracts that no longer exists), the wasm Stargate-query whitelist entries for tokenfactory (`app/queries/queries.go`), and the `x/sanction` reference in the v8.4.0 upgrade handler (above). Also deleted: the module directories themselves, `testutil/keeper/{sanction,tax,tokenfactory}.go`, `proto/mantrachain/{sanction,tax}/`, `proto/osmosis/` (tokenfactory's only occupant), and the e2e test coverage for all three (`tests/e2e/e2e_sanction_test.go`, `tests/e2e/e2e_tokenfactory_test.go`, plus surgical cleanup of shared e2e files that referenced them). `x/` is now empty.

**Verified, not assumed:** `go build ./...` and `go vet ./...` both pass clean across the entire repo (root module + the e2e test files, which needed their own fixes for stale references). A local single-node devnet boots from genesis, produces blocks, and processes a real signed `MsgSend` transaction (see "Smoke test" below) with the stripped module set.

### Circuit breaker (`cosmossdk.io/x/circuit`) — verified live, not just present

Already correctly wired before this session (keeper, store key, `app.SetCircuitBreaker(&app.CircuitKeeper)`, even threaded into wasm's own message router as an additional check) — confirmed by reading, then **verified by actually tripping it** on a live local node: granted a test key `LEVEL_SUPER_ADMIN` circuit permission (normally gov-gated via `MsgAuthorizeCircuitBreaker`; done directly in this local-only genesis for a fast test), disabled `/cosmos.bank.v1beta1.MsgSend`, confirmed a subsequent send was rejected at the ante-handler stage (`"code":1,"raw_log":"tx type not allowed"`), reset it, confirmed sends succeed again. Full transcript: `docs/proof/circuit-breaker-verification.log`.

### Bech32 prefix + denom rename — locked as of this session, per direct user decision

- Bech32 prefix: `mantra` → **`ark`** (`arkpub`/`arkvaloper`/`arkvaloperpub`/`arkvalcons`/`arkvalconspub`)
- Base denom: `amantra` → **`espees`** (18 decimals, display `espees`, symbol `ESP`, human unit `espees`)
- Devnet chain-id: kept as `arkdevnet_9000-1` (explicit user decision, unchanged)
- Mainnet EVM chain-id: **not locked** — proposing `ark_9001-1` (a distinct EVM number from devnet's `9000` to avoid any chain-id collision/replay-confusion risk) but this was not explicitly confirmed by the user; flag for sign-off before real mainnet genesis.

Fixed a real duplicate-definition hazard found while doing this: `app/params/config.go` and `cmd/mantrachaind/main.go` both independently defined the same `Bech32Prefix`/denom constants and both called `SetAddressPrefixes()`. Traced why this doesn't panic (`app/params/config.go`'s own `Seal()` call was already commented out — its `init()` runs first and sets values without sealing, `main()`'s `setupConfig()` runs second, re-sets the same fields, then seals) rather than assuming it was safe. Both files are now kept consistent (previously `app/params/config.go` had **stale** 6-decimal `om`/`uom` constants left over, not even matching pre-rename `mantra`/`amantra` — dead, unreferenced outside the file itself, confirmed via grep).

Also renamed, since they're the same branding-leak category and low-risk/self-contained: the EVM coin display denom in `app/app.go`'s `EVMCoinInfo` (`"mantra"` → `"espees"`), the live `MinGasPrices` default every validator gets (`cmd/mantrachaind/cmd/config.go`: `"0amantra"` → `"0espees"`), and the IBC-memo unwrap trigger key in `app/ibc_middleware/unwrap_erc20.go` (`{"mantra":{"unwrap":true}}` → `{"ark":{"unwrap":true}}` — a protocol-level identifier bearing MANTRA's name; safe to change now since Ark is a fresh chain with no existing integrations depending on the old key).

**Verified, not assumed:** built the binary fresh, generated a real key, confirmed the address comes back `ark1...` (`ark1mdzcudjcd80fy5rkpp5vtxu6u6mpstjffhe3la` in the smoke test below), re-encoded (not text-replaced — bech32 checksums are prefix-dependent) two hardcoded `mantra1...` test addresses in `tests/e2e/` to their real `ark1...` equivalents using the same 20-byte payload.

**Explicitly NOT done:** renaming the Go module path (`github.com/MANTRA-Chain/mantrachain/v8`), binary name (`mantrachaind`), or proto package namespace (`mantrachain.*`). These weren't asked for, are individually much larger/more disruptive changes (module path rename touches every import statement in the repo; binary rename affects every deployed script/systemd unit/doc), and conflating them with the bech32/denom decision risked scope creep beyond what was asked. Flagged as a separate decision if wanted.

**Left deliberately untouched, flagged not fixed:** `app/ibc_middleware/migrate_uom.go` — a MANTRA-specific one-time IBC middleware for migrating legacy `uom`→`amantra` denominated IBC vouchers from MANTRA's own historical 6→18 decimal transition. Inert for Ark (no chain will ever send Ark a `uom` voucher — Ark never had that denom), but not explicitly named in this track's scope, so left in place rather than removed unasked. `app/token_pair.go`'s `WTokenContractMainnet` constant (test/example-only wrapped-token address, used exclusively by the test-only `app.DefaultGenesis()` path) similarly flagged, not touched. See `GAPS.md`.

### Fork audits (real diffs, not descriptions from memory — full reports in `docs/proof/`)

Both audits shallow-cloned the actual fork and upstream repos and ran real `diff`/GitHub-compare-API comparisons.

- **`MANTRA-Chain/cosmos-sdk@v0.53.6-v8-mantra-1` vs upstream `v0.53.6`** (exact matching tag, precise diff): ~40 files touched, clustering into exactly two features — bank module `BeforeSend` hooks (Osmosis-style, opt-in/no-op by default) and a new `x/mint` `MaxSupply` param with a correct v2→v3 migration — plus one real behavior change worth a deliberate decision (`x/auth/tx/query.go` now silently drops undecodable txs from `GetTxsEvent` results instead of erroring the whole query). **The fork is measurably behind**: upstream has shipped v0.53.7 and v0.53.8 past the fork's pin (32 commits), including secp256k1 pubkey-tag validation and a compact-bitarray bounds fix that the fork's pinned commit does not have (byte-diff confirmed unchanged from v0.53.6 baseline). Full report: `docs/proof/fork-audit-cosmos-sdk.md`.
- **`MANTRA-Chain/evm@v0.6.2-v8-mantra-1` vs upstream**: go.mod's own `require` line claimed `v0.6.0` but the fork is actually built on real upstream `v0.6.2` (confirmed via `git describe`) — **fixed** (`go.mod` now correctly says `v0.6.2`; the `replace` directive, which is what actually governs compilation, was already correct and unaffected). True MANTRA-authored patch set (v0.6.2→fork) is 42 files/~1,123 lines. **No branding/vanity glue found at all** — every substantive change is a genuine fix or ops hardening. Most consequential finding: **the fork backports the critical ICS20 reentrancy guard (upstream PR #1061) that closed the vulnerability class behind the real $7M Saga exploit — and upstream itself has not shipped this fix to its own v0.6.x line as of v0.6.2 (published 3 days before this audit as a dedicated security release, and still lacking it)**. One change (EIP-7623 post-refund gas-floor enforcement) appears to be MANTRA-original and unreviewed by upstream — flagged for the most independent scrutiny of anything in the diff. Full report, including the complete keep/review file list: `docs/proof/fork-audit-cosmos-evm.md`.

### Smoke test — genuinely run, not asserted (`docs/proof/circuit-breaker-verification.log` covers the circuit-breaker half)

Single local node, chain-id `circuit-test-1`, binary built from this branch's HEAD:
1. `genesis validate-genesis` passes.
2. Node boots, produces blocks (reached height 3+ within 8s of start).
3. Real signed `MsgSend` (val → recipient, `1espees`... `1000000000000000000espees`) broadcasts, lands, balance query confirms receipt.
4. Circuit breaker disable/reject/reset/allow cycle (see above).

### Tag

**`ark-v0.1.0-alpha`** — cut at the commit that adds this STATUS.md, after the smoke test above passed. This is a **first compiling, booting build with the named modules stripped and Ark's own bech32/denom identity applied** — not a claim that EVM wiring, precompile/feemarket decisions, or anything in Day 2/3 below is done.

---

## Day 2 (partial — see explicit blocker below)

### Precompile audit (`x/vm/types.AvailableStaticPrecompiles` + Ark's own `distrclaim`)

None of these are active by default at genesis (`mantrachaind init`'s raw output has `active_static_precompiles: []`) — enabling any of them is a deployment-time genesis-patch decision, same as denom/erc20 config. Recommendation for that patch, one line each:

| Precompile | Address | Recommendation | Reason |
|---|---|---|---|
| Bech32 | `...0400` | **Enable** | Directly supports the dual bech32/0x address model this chain relies on; near-zero attack surface (pure encoding, no state access). |
| Bank | `...0804` | **Enable** | Core to the "one account, two address forms" model — contracts need native-side balance/transfer access without going through an ERC20 wrapper. |
| Staking | `...0800` | **Enable, flag for Eng 3** | Real utility (direct-delegate UX, liquid-staking/restaking integrations) but the largest attack surface of the batch — invokes staking state transitions from an EVM entry point. Wants dedicated chaos coverage before mainnet. |
| Distribution | `...0801` | **Enable** | Reward claiming/withdrawal from EVM; mostly reads + self-directed withdraws, lower risk than staking. |
| ICS20 | `...0802` | **Enable, flag for Eng 3 — highest priority** | The single most valuable precompile for EVM×IBC interop, and simultaneously the one with a real-world exploit history (the Saga incident this exact vulnerability class caused). The fork already carries the critical reentrancy fix (see fork audit above) - the fix being present is necessary but not sufficient; this is exactly where chaos/adversarial testing belongs first. |
| Gov | `...0805` | **Enable** | Useful for DAO/on-chain-governance tooling built on Ark; normal msg-sender authorization already gates who can vote as whom. |
| Vesting | `...0803` | **Enable** | Niche, narrow, low risk. |
| Slashing | `...0806` | **Enable** | Query + self-service unjail only; low risk. |
| P256 | `...0100` | **Enable** | WebAuthn/passkey signature verification (RIP-7212) - relevant to account-abstraction/Paymaster UX goals; no state access. |
| `distrclaim` (Ark custom, `...0a01`) | Ark-native | **Enable** | Narrow, single-purpose (claim rewards + convert to ERC20-wrapped coin in one call), custom-authored so smaller trusted surface than the vendored precompiles above. |

No "disable, unnecessary attack surface" calls ended up warranted on this pass - every precompile in the catalog has a concrete, named use case for this chain's stated direction (dual address model, AA/Paymaster UX, EVM×IBC interop). If anything gets cut, it should be a deliberate later call once real usage data or Eng 3 findings suggest a specific one isn't earning its risk.

### `skip-mev/feemarket` dynamic fee configuration

**Decision: keep the vendored defaults** (`base_fee_change_denominator: 8`, `elasticity_multiplier: 2`, `min_gas_price: 0`, `base_fee: 10^9` atto-units ≈ 1 gwei-equivalent at 18 decimals) rather than override them. Reasoning, specifically for the gasless-tx/Paymaster direction: `min_gas_price: 0` means a Paymaster-sponsored meta-transaction is never blocked by a nonzero mempool floor regardless of what fee the end user's own wallet would otherwise need to post; the EIP-1559-style elasticity (`denominator=8` → base fee moves at most 1/8 per block, `multiplier=2` → 50%-full target block) gives a Paymaster relay predictable, slowly-changing fee costs to budget against rather than the sharp per-block swings a more aggressive denominator would produce. This is a "keep the reasoned default" decision, not an unreviewed accident.

### Eng 3 dependency — checked, not fabricated

Checked GitHub directly for a `track/3-security-chaos` branch or any Eng-3-authored PR: **neither exists yet** (`gh api .../branches` and `gh pr list --state all` both come back empty for track/3). This matches the task's own prediction exactly ("those don't exist yet on a fresh start, since Eng 3 needs your Day 1 tag first"). No chaos findings are fabricated or simulated anywhere in this document.

### Day 2 tag

**Not cut in this session.** Day 2's explicit scope (precompile audit, feemarket config) is done above and could support a tag, but per the task's own instruction this needs to be "clearly flagged as pending Eng 3 validation" — and since Eng 3 has published nothing at all yet (not even a preliminary report to caveat against), tagging `ark-v1.0.0-rc1` right now would produce a tag whose name (`rc1` = "suitable for multi-validator testnet" per `CONTRIBUTING.md`'s versioning table) overstates its actual validation status. Recommend cutting `ark-v1.0.0-rc1` once Eng 3 has published *something* to reference in the tag's caveat, even a "nothing found yet" preliminary note — not simulating that input to unblock a tag today.

---

## Day 3 — not started, honestly

Day 3's own gate ("Only cut this if Day 2's Eng 3 dependency has genuinely closed") isn't met — Day 2 itself isn't tagged yet, pending real Eng 3 input as above. Producing reproducible build hashes and release artifacts before that would be real, useful work, but cutting a **final** `ark-v1.0.0` tag under an explicitly still-open external dependency would be exactly the "confident guess that turns out wrong" the task asked to avoid. Reporting this as blocked-on-Eng-3, not attempting a workaround.
