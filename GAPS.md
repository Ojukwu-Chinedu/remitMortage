# GAPS — Eng 1 (State Machine) track

What's still open, blocking, or needs a follow-up decision. See `STATUS.md` for the full narrative of what was done and verified; this file is the punch list.

## Blocking Day 2/3 progression

- **Eng 3 has published nothing yet** (checked directly: no `track/3-security-chaos` branch, no PR). `ark-v1.0.0-rc1` should not be cut with a fabricated or simulated chaos sign-off — wait for real input, even a preliminary "nothing found yet" note.
- **`ark-v1.0.0` (final) cannot honestly be cut** until the above closes AND `rc1` itself is tagged. Day 3's reproducible-build/checksum work can start independently of this (it doesn't depend on Eng 3), but the *tag* should wait.

## Decisions made this session that need explicit sign-off, not silent adoption

- **Mainnet EVM chain-id proposed as `ark_9001-1`** (distinct from devnet's `9000` to avoid replay/collision risk) — this was **not** explicitly confirmed by the user, only devnet's `arkdevnet_9000-1` was. Confirm before it's load-bearing anywhere real.
- **Precompile audit recommends enabling all 10** (see `STATUS.md`'s table) — reasoned, but review-and-agree, not rubber-stamp, especially Staking and ICS20 (flagged for Eng 3 chaos coverage specifically).
- **`skip-mev/feemarket` config kept at vendored defaults** rather than tuned — reasoned against the gasless/Paymaster goal, but never load-tested against real Paymaster relay traffic patterns.

## Explicitly flagged, not fixed (out of this track's asked-for scope)

- **`app/token_pair.go`'s `WTokenContractMainnet`** — a "mainnet"-named wrapped-token contract address, used only by the test-only `(app *App).DefaultGenesis()` path (`app/test_helpers.go`, `tests/e2e/chain.go` — never the real `mantrachaind init` path). Worth a second look for whether it's a real MANTRA mainnet address that shouldn't appear in Ark's test fixtures at all, same category as the two blacklisted-address findings below, but not verified either way this session.
- **Full README/docs rebrand** — only the `README.md` "Modules" section was corrected (it described the three now-removed modules as present, which would have been actively misleading). No attempt at a full MANTRA→Ark rebrand of the rest of `README.md`/`CONTRIBUTING.md`, since this branch was cut from `main` (pure upstream MANTRA content, no Ark branding at all yet) rather than `base-genesis` (which already has an Ark-rebranded README from a separate commit) — reconciling these when this branch merges is a real integration step, not automatic.
- **Go module path / binary name / proto namespace** (`github.com/MANTRA-Chain/mantrachain`, `mantrachaind`, `mantrachain.*` proto packages) — deliberately not renamed alongside bech32/denom. Same "MANTRA branding visible in Ark's own identity" category, but a much larger, more disruptive change (touches every import statement, every deployed script/service assuming the binary name) that wasn't explicitly asked for. Flag as a separate decision if wanted — don't assume it's implied by the bech32/denom rename.

## Real findings from this session worth carrying forward

- **`app/genesis.go`'s dead `NewDefaultGenesisState()`** was removed rather than fixed-and-wired-in — see `STATUS.md` for the full reasoning (it was also broken, would have panicked on an empty erc20 TokenPairs slice). If a future session wants genesis customization baked into the binary itself rather than the deployment-time patch process, that's a deliberate re-decision, not a revert of a bug fix.
- **Hardcoded real MANTRA mainnet address in `x/tax` eliminated**: `x/tax`'s `DefaultMcaAddress` was removed with the module removal, and legacy incident-response upgrade scheduling in `PreBlocker` was cleaned up. Genuine production MANTRA data has no place in Ark's codebase. Worth a final grep sweep (`grep -rn "mantra1[a-z0-9]\{30,\}"`) before any real mainnet genesis day, in case another instance exists somewhere not touched by this track's specific module-removal work.
- **Cosmos SDK fork is measurably behind upstream on two real fixes** (secp256k1 pubkey-tag validation, compact-bitarray bounds check — both landed in v0.53.7/v0.53.8, past the fork's v0.53.6 pin). Not urgent (neither is a published CVE against the pinned version), but worth tracking for the next SDK re-pin. Full detail: `docs/proof/fork-audit-cosmos-sdk.md`.
- **cosmos/evm fork's EIP-7623 post-refund gas-floor change appears MANTRA-original and unreviewed by upstream** (not found in upstream through v1.0.0-rc2). Everything else in that fork's diff is either a verified upstream backport or config/test-only. This one specific change is the highest-value target for independent testing (refund-heavy, large-calldata Prague-path transactions) before trusting it in production. Full detail: `docs/proof/fork-audit-cosmos-evm.md`.
- **`go.mod`'s `cosmos/evm` require line was stale** (`v0.6.0` vs the actually-compiled `v0.6.2` base) — fixed this session (cosmetic, since the `replace` directive already governed real compilation, but was misleading to tooling/auditors). Worth checking whether any other `require` lines have similarly drifted from their `replace` targets.
