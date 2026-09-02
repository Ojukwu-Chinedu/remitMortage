# ASA-2026-002 / GHSA-54gx-3cgr-7mfm — ICS20 nested-forwarding exposure

**Verdict: NOT vulnerable.** The `#1061` source-callback guard is present, correct, and
byte-identical to upstream in the evm fork the genesis chain actually builds against
(`Worldstreet-Web-Services/evm v0.6.2-ark-1`). The guard **survived the ark-1 rebase intact**.

- **Scope:** ASA-2026-002 only (ICS20 precompile nested-forwarding double-spend, cosmos/evm).
- **Date:** 2026-09-01.
- **Investigation:** read-only. No code changed. No PR opened.
- **Method note:** the in-environment mutation test (Step 5) could **not** run — the Go module
  proxy (`proxy.golang.org`) is unreachable from this box (IPv6 timeout). That is an
  environment limitation, not a code finding. It was substituted with something stronger:
  a byte-level diff of every guard file against upstream `#1061` and against the mantra
  parent, plus a full static context-propagation trace. GitHub git access works, so the
  upstream/org/fork comparisons below are real, not inferred.

---

## 1. Answer to the lead's question

**NOT vulnerable.** The chain the org builds/deploys links `v0.6.2-ark-1`, and the `#1061`
guard survived that rebase intact.

### Deployed artifact vs source — three artifacts, do not conflate

The mirror this clone points at and the org repo describe **different builds**. Established
directly (org tree fetched at `b0145a26`, image tags read from the org `ops/`):

| # | Artifact | evm pin | Guard status |
|---|----------|---------|--------------|
| A | `ark-v1.0.0` **git tag** + `ghcr.io/…/arkd:ark-v1.0.0` image — pulled **only** by the *stale mirror's* `ops/docker/Dockerfile.node` (`FROM ghcr…/arkd:ark-v1.0.0`) | mantra parent `v0.6.2-v8-mantra-1` | present & correct ✅ |
| B | `arkd` built **from source** on the org `base-genesis` (`b0145a26`) — the org's `ops/docker/Dockerfile.node` was rewritten to `make build` from source (`FROM golang:… AS builder` → `COPY --from=builder /src/app/build/arkd`) | `v0.6.2-ark-1` | survived rebase intact ✅ |
| C | `ghcr.io/worldstreet-web-services/arkd:ark-v1.0.1` — the default image in the org `ops/docker/docker-compose.devnet.yml` (`image: ${ARKD_IMAGE:-…arkd:ark-v1.0.1}`) | **not provable from git** | expected `ark-1`, **provenance unconfirmed** ⚠️ |

Reading:

- **The mirror's deployment (A) is stale.** It pulls the `ark-v1.0.0` image, which is built
  from the `ark-v1.0.0` git tag and links the **mantra parent** — a build that predates the
  ark-1 evm bump (bump landed on the org `base-genesis` on 2026-08-26, after the mirror's last
  sync). Guard there is present and correct, but that is **not** what the org runs now.
- **The org's current source build (B) is the real one.** Its `Dockerfile.node` builds `arkd`
  from the org tree, which pins `v0.6.2-ark-1`. This is the artifact §1's verdict is about.
- **The devnet image `ark-v1.0.1` (C) is the intended running image**, but there is **no
  `ark-v1.0.1` git tag** in the org repo (only `ark-v1.0.0` exists), so its exact source commit
  and evm pin **cannot be proven from git**. It was cut alongside the `b0145a26` commit
  (message: "update devnet compose with ark-v1.0.1 image"), so it is *expected* to be an
  `ark-1` build — but that must be **confirmed by inspecting the image** (build labels /
  `go version -m /usr/local/bin/arkd`) or by rebuilding from a pinned commit. **Flagged, not
  assumed.**

**Bottom line for the lead:** every artifact the org currently builds or deploys is either
verified `ark-1`-with-intact-guard (B) or expected-`ark-1`-pending-image-confirmation (C); the
only mantra-parent artifact (A) is the stale mirror's and is also guard-safe. No artifact is
vulnerable to ASA-2026-002; the one open item is confirming the `ark-v1.0.1` **image**'s
provenance.

### Evidence (for the `v0.6.2-ark-1` fork that B builds against)

1. **Guard present in `v0.6.2-ark-1`.** Symbols `IsSourceCallbackExecution` /
   `WithSourceCallbackExecution` / `ErrNestedSourceCallbackTransfer` exist in
   `precompiles/ics20/tx.go`, `x/ibc/callbacks/types/context.go`,
   `x/ibc/callbacks/types/errors.go`, both `keeper.go` call sites, and the guard test.
2. **All six guard files are byte-identical to the mantra parent `v0.6.2-v8-mantra-1`**
   (`diff` empty). The ark-1 rebase did not touch them.
3. **The mantra parent's guard files are in turn logic-identical to upstream cosmos/evm**
   at the `#1061` merge commit `20c00074a640d5ef7d4979f067f599a86badf2a3`
   (`fix(ibc): block nested ICS20 forwarding in src callbacks (#1061)`, mmsqe, 2026-04-28).
   The only differences are expected fork skew: `ibc-go v11 → v10` import paths and the
   `storetypes` import path. **The guard is a faithful copy of upstream, not a variant.**
4. **Ordering is correct** in both callbacks: `WithSourceCallbackExecution` is applied
   **after** `BuildEvmExecutionCtx`, and the marked `cachedCtx` feeds both the `stateDB`
   and `CallEVM` (`keeper.go:302` Ack, `keeper.go:404` Timeout).
5. **Propagation machinery intact.** Of the five propagation-critical files,
   `statedb.go`, `call_evm.go`, `state_transition.go`, and `ics20.go` are byte-identical
   between ark-1 and the mantra parent. `precompiles/common/precompile.go` differs only in
   gas/error handling (an `ErrOutOfGas` special-case removed from the outer wrapper; the
   `HandleGasError` defer moved earlier) — neither hunk is on the ctx path, and the guard's
   blocking behavior is unchanged.

### The 12-hop trace (marked ctx → guard fires)

File:line are for `v0.6.2-ark-1` (identical to the mantra parent unless noted):

1. `x/ibc/callbacks/keeper/keeper.go:299` (Ack) / `:401` (Timeout) — `cachedCtx, writeFn := ctx.CacheContext()`
2. `keeper.go:300` / `:402` — `cachedCtx = evmante.BuildEvmExecutionCtx(cachedCtx).WithGasMeter(…)`
3. `keeper.go:302` / `:404` — `cachedCtx = types.WithSourceCallbackExecution(cachedCtx)` ← **marker set (after BuildEvmExecutionCtx)**
4. `keeper.go:303` / `:405` — `stateDB := statedb.New(cachedCtx, …)` → `x/vm/statedb/statedb.go:156` stores `s.ctx = cachedCtx` (marked)
5. `keeper.go:330` (Ack, `cachedCtx`) / `:430` (Timeout, **`ctx`** — see §4) — `k.evmKeeper.CallEVM(<ctx>, stateDB, …)`
6. `x/vm/keeper/call_evm.go:23` `CallEVM` → `CallEVMWithData` → `x/vm/keeper/state_transition.go:333` `ApplyMessage` → `:381` `ApplyMessageWithConfig`
7. `state_transition.go:36` `NewEVMWithOverridePrecompiles(ctx, msg, cfg, tracer, stateDB, …)` → `vm.NewEVMWithHooks(…, stateDB, …)` — **passed (marked) stateDB handed to the EVM; `s.ctx` never reset** (no `WithContext`/`SetContext` exists on StateDB)
8. contract calls the ICS20 precompile → `precompiles/ics20/ics20.go:106` `Run` → `RunNativeAction` (`precompiles/common/precompile.go`)
9. `precompiles/common/precompile.go:58` — `stateDB := evm.StateDB.(*statedb.StateDB)` (the marked one)
10. `precompiles/common/precompile.go:64` — `ctx, err := stateDB.GetCacheContext()` → `statedb.go:177` → `:202` `s.cacheCtx, _ = s.ctx.CacheContext()` (**`CacheContext` preserves the `WithValue` marker**)
11. `precompiles/common/precompile.go:91` — `ctx = ctx.WithGasMeter(…)` (marker preserved) → `:107` `bz, err = action(ctx)` → `ics20.go:111` `p.Transfer(ctx, …)`
12. `precompiles/ics20/tx.go:194-195` — `if IsSourceCallbackExecution(ctx) { return nil, ErrNestedSourceCallbackTransfer }` → **true → transfer blocked** → `RunNativeAction` → `ReturnRevertError` (reverted). ✅

Guard block, verbatim (`precompiles/ics20/tx.go`):

```go
185  // Transfer implements the ICS20 transfer transactions.
186  func (p *Precompile) Transfer(
187  	ctx sdk.Context,
188  	contract *vm.Contract,
189  	stateDB vm.StateDB,
190  	method *abi.Method,
191  	args []interface{},
192  ) ([]byte, error) {
193  	// Marker is set in the callbacks keeper and propagates here via cacheCtx.
194  	if callbackstypes.IsSourceCallbackExecution(ctx) {
195  		return nil, callbackstypes.ErrNestedSourceCallbackTransfer
196  	}
```

Both callback paths are protected. The Timeout-path `ctx`/`cachedCtx` bug (§4) does **not**
defeat the guard, because the marker travels via the stateDB, not via the `CallEVM` ctx arg.

The underlying v0.6.0 state-handling fix (distinct from the `#1061` guard) is also present:
`RunNativeAction` snapshots (`MultiStoreSnapshot`), journals a revertable precompile entry
(`AddPrecompileFn`), commits pending EVM writes into the cache ctx **before** the call
(`FlushToCacheCtx`), and reconciles balances after — the post-fix design. Base is `v0.6.2`
(> `v0.6.0`), consistent with this.

---

## 2. Open question for the lead — RESOLVED, with one residual

Earlier in this investigation the local clone showed *nothing* consuming `v0.6.2-ark-1`, which
raised the question "is genesis meant to ship the ark evm layer, or is there a wiring gap?"

**That was a stale-mirror artifact (see §3). Resolved:** the org `base-genesis` (the real
genesis source) **does** consume the ark evm layer:

```
# github.com/Worldstreet-Web-Services/ArkConstellation @ base-genesis (b0145a26, 2026-08-26)
github.com/cosmos/evm => github.com/Worldstreet-Web-Services/evm v0.6.2-ark-1
```

So genesis ships `ark-1`, and the ark-1 guard-survival audit that this task really needed
**has been done** (§1): the guard survived intact. No decision is blocked on ASA-2026-002.

**Residual (separate from ASA-2026-002, do not conflate):** the ark-1 rebase is a
~34-file / ~3000-line layer on the mantra parent. This report verified only the ICS20
source-callback guard and its propagation path. A full ark-1 fork-diff audit remains owed as
its own task in the evm fork repo — it is out of scope for ASA-2026-002 but must not be
assumed clean. **In fact it is not clean:**

> **CONFIRMED regression in ark-1 — `x/erc20/v2/ibc_middleware.go` dropped IBC-v2
> acknowledgement validation** (the exact file the earlier audit flagged). Verified 2026-09-02
> by diffing `v0.6.2-ark-1` against the mantra parent `v0.6.2-v8-mantra-1`. Relative to the
> parent, ark-1:
> - **`OnRecvPacket` (IBC-v2):** ignores the keeper's returned modified acknowledgement —
>   drops the `!modifiedAck.Success()` failure check and the ack-modification detection, and
>   returns the original `recvResult` instead of `modifiedAck`.
> - **`OnAcknowledgementPacket` (IBC-v2):** drops two checks — the ack-bytes **round-trip
>   integrity** check (`bz != acknowledgement → ErrInvalidType`) and the **reject-custom-error-ack**
>   check (`!ack.Success() → ErrInvalidRequest "cannot pass in a custom error acknowledgement
>   with IBC v2"`).
>
> This is **not** ASA-2026-002 (the ICS20 guard is intact) but it **is** a real
> dropped-safety-code regression matching the documented ark-1-rebase pattern. **Severity
> resolved in §6: dead code at genesis (IBC-v2 path unwired), so latent — but it ships in
> `v0.6.2-ark-1` and goes live the moment IBC-v2 is enabled.** The drop is confirmed present in
> the fork the genesis chain builds against, and was already flagged in the fork-audit issue
> tracker (still unfixed).

---

## 3. Caveat — remote / mirror status

**All first-pass conclusions were computed against a stale personal mirror, not the org repo.
This was caught and corrected before this report; the §1 verdict is against the org/fork.**

- The local clone has **one** remote: `origin = git@github-ojukwu:Ojukwu-Chinedu/remitMortage.git`
  — a personal mirror, not `Worldstreet-Web-Services/ArkConstellation`. No remote points at the org.
- Local `HEAD` == mirror `origin/base-genesis` == `4b70032f` (0 ahead / 0 behind the mirror).
- Mirror is **stale**: last fetch 2026-08-25; newest commit on any mirror branch 2026-08-25 13:58.
- The **org** `base-genesis` is a **different, newer** commit: `b0145a26` (2026-08-26). Verified
  directly via `git ls-remote` + shallow `git fetch` of the public org repo (GitHub reachable).
- The divergence is material: the mirror's `base-genesis` still pins the **mantra parent**
  (`MANTRA-Chain/evm v0.6.2-v8-mantra-1`); the org's `base-genesis` pins the **ark fork**
  (`Worldstreet-Web-Services/evm v0.6.2-ark-1`). The evm bump landed on the org on 2026-08-26,
  after the mirror's last sync.

Plainly: had this stopped at the mirror, the answer would have been correct for the wrong
artifact. The verdict in §1 is stated against the org's `base-genesis` and the `v0.6.2-ark-1`
fork, both fetched directly. **Recommendation:** re-point `origin` at the org repo (or add it
as a second remote) so future audits are not run against a stale mirror by default.

---

## 4. Secondary findings (real, but not guard bypasses)

These were surfaced by the file-level diffs. None defeats the ASA-2026-002 guard; all live in
both the mantra parent and `v0.6.2-ark-1` (inherited, not ark-introduced).

1. **Timeout path passes the wrong ctx to `CallEVM`** — `x/ibc/callbacks/keeper/keeper.go:430`
   calls `CallEVM(ctx, …)` (the unmarked original) where upstream and the Ack path use
   `CallEVM(cachedCtx, …)` (the marked, infinite-gas-metered ctx). **Not a guard bypass** —
   the EVM executes against the marked `stateDB`, and the precompile reads its ctx from
   `stateDB.GetCacheContext()`, so the marker is present regardless of the `CallEVM` ctx arg
   (verified: `NewEVMWithOverridePrecompiles` never resets `stateDB.ctx`). It is a **gas /
   correctness bug**: it reintroduces the infinite-gas-meter concern that the adjacent code
   comment explicitly warns about for the timeout callback. Worth fixing and upstreaming.
2. **Copy-paste telemetry label** — `keeper.go:437` consumes gas with the label
   `"callback onPacketAcknowledgement"` inside the **timeout** function (upstream:
   `"callback onTimeoutPacket"`). Cosmetic (telemetry only); a marker that this block was
   hand-edited and diverged from upstream, which is why finding #1 exists.
3. **Missing `contractAddr != sender` restriction** — upstream main has, in both callbacks,
   `if contractAddr != sender { return ErrCallbackFailed }` ("source callback contract must
   match packet sender"); the v0.6.2-based fork lacks it. Confirmed via the `20c00074` commit
   diff that this is **NOT part of `#1061`** — it is separate, later upstream evolution.
   **Out of scope** for ASA-2026-002; optional hardening to consider as its own backport.

---

## 5. Exposure

**Live exposure is non-zero from a feature standpoint; safety rests on the guard code, not on
the feature being disabled.** Re-verified against the **org `base-genesis` (`b0145a26`)** —
i.e. *after* the `v0.6.2-ark-1` evm bump — not the stale mirror. The precompile-registration
and genesis-activation regions of `app/app.go` are byte-identical between the mirror
(`4b70032f`) and the org (`b0145a26`), so the bump did not change app-level exposure.

- The ICS20 precompile is **enabled**: `evmtypes.AvailableStaticPrecompiles` includes the ICS20
  address (`0x…0802`), `DefaultStaticPrecompiles` constructs it (`WithICS20Precompile`,
  `app/app.go:748`), and `app/app.go:1284` activates the full available set in genesis params.
- The IBC callbacks middleware is **wired** into the transfer stack, including the source-callback
  send path (`app/app.go:716` `NewKeeper`, `:721` `NewIBCMiddleware(transferStack, …)`,
  `:728` `WithICS4Wrapper(&callbacksMiddleware)`). The `onPacketAcknowledgement` /
  `onPacketTimeout` callbacks that the guard defends are reachable.
- Therefore this chain is **not** in the "unaffected because the feature was off" category. It is
  safe **only** because the guard code is intact. A future evm-dependency bump that dropped or
  broke the guard would make the chain immediately exploitable, silently. This is why the pin is
  safety-critical and why a guard regression check in CI is the right follow-up (see below).
- **Pre-mainnet.** This is genesis-rehearsal / devnet stage; there is no running mainnet with a
  live exploitable path, so no emergency private-disclosure trigger applies.

---

## 6. Severity of the ark-1 erc20 IBC-v2 ack-validation regression (§2)

Severity resolved by the **same method as §5** — reading the actual wiring in the org
`base-genesis` (`b0145a26`) `app/app.go`, i.e. the tree that pins `v0.6.2-ark-1`.

**Wiring facts (all from org `app/app.go` @ `b0145a26`):**

- **No import of `cosmos/evm/x/erc20/v2` anywhere.** Only the v1 packages are imported:
  `x/erc20`, `x/erc20/keeper`, `x/erc20/types` (`app.go:132-134`). The regressed file
  `x/erc20/v2/ibc_middleware.go` is not referenced.
- The erc20 middleware wired into the transfer stack is the **v1** one:
  `transferStack = erc20.NewIBCMiddleware(app.Erc20Keeper, transferStack)` (`app.go:715`).
- The **only** IBC-v2 reference in the whole file is `nil, // channelkeeperv2` (`app.go:807`) —
  and it is a parameter to the **`WasmKeeper` constructor**, i.e. wasm's v2 channel keeper is
  explicitly nil. **No v2 channel keeper is constructed anywhere.**
- No IBC-v2 router / v2 transfer module / v2 packet path is registered (`SetRouterV2`,
  `transfer/v2`, `ChannelKeeperV2.New`, `OnRecvPacketV2`, … — none present).

**Severity: DEAD CODE AT GENESIS — not reachable.** The dropped `OnRecvPacket` /
`OnAcknowledgementPacket` validation lives on the IBC-v2 (Eureka) path, and that path is not
wired: the v2 erc20 middleware is not imported, the transfer stack uses the v1 middleware, and
the v2 channel keeper is nil — so no IBC-v2 packet can be received or acknowledged on this chain
as shipped. The regressed code cannot be triggered at genesis. **Latent, not live.**

**But it is a latent landmine, not a non-issue.** The moment IBC-v2 / Eureka is enabled (a
non-nil `channelkeeperv2` + a v2 router + registering the v2 erc20 middleware), the dropped
checks go live with no further warning — and the regression ships in the exact tag genesis
builds against (`v0.6.2-ark-1`).

**Tracker status:** this regression was already documented in the **fork-audit issue tracker**
(the earlier audit that first caught the ark-1 rebase silently dropping this validation) and
**remains unfixed in `v0.6.2-ark-1`** — the tag the genesis chain ships. Note for accuracy: the
local `docs/proof/fork-audit-cosmos-evm.md` documents the ICS20 `#1061` guard but was written
against the **mantra parent**, not ark-1, and does **not** record this erc20-v2 drop; the issue
tracker is the system of record for it.

**Recommendation:** not an emergency (dead code today), but (a) restore the dropped checks in
`Worldstreet-Web-Services/evm` before any IBC-v2 enablement, and (b) gate it — no IBC-v2 wiring
should merge until the ack-validation is back in place.

---

## Suggested follow-up (not done here — no PR was opened)

- Add a guard **regression test** to the chain repo that builds against the pinned evm and asserts
  a marked-ctx `Transfer` returns `ErrNestedSourceCallbackTransfer`; make it a required status
  check on `base-genesis`. This catches a silent guard-dropping dependency bump — the real risk.
- File the two mantra-fork bugs in §4 (items 1–2) upstream against `Worldstreet-Web-Services/evm`.
- Open a separate task for the full `v0.6.2-ark-1` fork-diff audit (§2 residual), starting with
  `x/erc20/v2/ibc_middleware.go`.
- **Confirm the `ark-v1.0.1` image provenance (§1 artifact C):** it is the devnet default image
  but has no matching git tag. The image is **private** (ghcr returns `unauthorized`
  unauthenticated), so this needs a registry credential: `docker login ghcr.io`, then
  `docker run --rm --entrypoint go ghcr.io/worldstreet-web-services/arkd:ark-v1.0.1 version -m
  /usr/local/bin/arkd | grep cosmos/evm` (or read the image build labels) to confirm it links
  `Worldstreet-Web-Services/evm v0.6.2-ark-1`, or rebuild from a pinned commit and re-tag. Until
  then its evm pin is expected, not proven.
- **Triage the confirmed ark-1 erc20 IBC-v2 ack-validation regression (§2):** confirmed present;
  assess IBC-v2 wiring/reachability to rank severity, then restore the dropped checks upstream in
  `Worldstreet-Web-Services/evm`.
- Re-point `origin` at the org repo (§3).
