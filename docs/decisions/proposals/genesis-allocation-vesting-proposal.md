# PROPOSAL: ArkConstellation (KASH) Genesis Allocation & Vesting Table

**Status:** 🟠 PROPOSAL — not decided, not locked. This is a draft for review, not an
approved schedule. It requires explicit sign-off from whoever actually owns
tokenomics/legal/business decisions on this team — not Eng 1-4, and not whoever
drafts documents — before any figure in it can be treated as something engineering
builds against or something marketing/legal can publish externally.

**Author:** Drafted for review, 2026-08-24.

**Depends on:** [`total-supply-proposal.md`](./total-supply-proposal.md)'s recommended
**1,000,000,000 KASH** genesis total supply, which is *itself* still an unapproved
proposal, not a locked figure. Every amount below is computed against that number
and will need to be recomputed if the supply figure changes before both are
approved together.

**Fills:** The blank "Token Distribution" table in
`docs/decisions/module-and-config-decisions.md` (the five rows currently marked
`—`) and unblocks decision #15 (min governance deposit) once a total is also
adopted.

**Does not contain:** Any real wallet address. No addresses exist yet — the
admin/upgrade multisig (decision #17) and any team/foundation/validator wallets
are all separately pending, out of scope here. Where a schedule needs to reference
"the team wallet" or "the foundation wallet," treat that as a placeholder role,
not an address.

---

## Summary

| Category | % of supply | KASH amount | Genesis-day liquid | Cliff | Linear vest | Fully unlocked at |
|---|---|---|---|---|---|---|
| Community / Ecosystem | 45% | 450,000,000 | 45,000,000 (10% of category, into community pool) | none | 8yr, 32 equal quarterly tranches | +8yr |
| Validator & Staking Incentives | 22% | 220,000,000 | 0 (streams to distribution module, never a wallet) | none | 6yr, continuous linear | +6yr |
| Foundation Reserve | 16% | 160,000,000 | 0 | 15mo | 45mo linear | +5yr |
| Team / Core Contributors | 15% | 150,000,000 | 0 | 12mo | 36mo linear (60mo if any single grant >1% of supply) | +4yr (+5yr for outsized grants) |
| Initial Validator Self-Delegation Bonds | 2% | 20,000,000 (2,000,000 × 10 validators) | 20,000,000 — liquid, immediately self-bonded | n/a — not vested | n/a | immediate (subject to 21-day unbonding once unbonded) |
| **Total** | **100%** | **1,000,000,000** | **≤65,000,000 (≤6.5%)** | | | |

Genesis-day maximum liquid/bondable float is **6.5% of total supply at most** — and
of that, 4.5 points sit in a protocol-owned governance-gated community pool, not a
private wallet, so the maximum any single non-protocol holder controls at genesis
is one validator's 2,000,000 KASH self-delegation (**0.2% of supply**). See
["Genesis-day liquidity snapshot"](#genesis-day-liquidity-snapshot) below.

---

## Genesis-day liquidity snapshot

The number that matters for concentration risk isn't the allocation percentages —
it's what's actually movable the day the chain goes live. This is the design
target this proposal is built around:

| Holder type | Amount liquid at genesis | % of total supply | Notes |
|---|---|---|---|
| Any single initial validator | 2,000,000 KASH | 0.2% | Immediately self-bonded, not sitting in a spendable wallet |
| All 10 initial validators combined | 20,000,000 KASH | 2.0% | Identical amount each — no validator starts with an outsized share |
| Community pool (protocol-owned, governance-gated) | 45,000,000 KASH | 4.5% | Not privately held; every spend needs its own passed governance proposal |
| Team | 0 | 0% | Full 12-month cliff, zero exceptions |
| Foundation | 0 | 0% | Full 15-month cliff, zero exceptions |
| Validator & Staking Incentives pool | 0 in any wallet | 0% | Streams directly into the distribution module; no liquid balance ever accumulates in a discretionary account |
| **Maximum any private (non-protocol) party controls** | **2,000,000 KASH** | **0.2%** | |

Compare to the MANTRA (OM) precedent this proposal is explicitly designed against:
top-10 wallets held **~53%** of OM's supply at the time of its April 2025 crash.
Under this design, the largest private holding at genesis is roughly **265x
smaller**, proportionally, than that reference point.

---

## Category detail

### 1. Community / Ecosystem — 45% (450,000,000 KASH)

**Largest single bucket by design** — the research survey consistently found
community/ecosystem allocations should be the largest category, not a residual
left over after insider buckets are filled, and 45% here exceeds every peer
chain's comparable figure (Injective ~57%* combined public buckets vs. this
chain's ecosystem-only 45%, dYdX ~57% combined vs. 45% ecosystem-only — using the
stricter single-category comparison since ArkConstellation doesn't have separate
trading-rewards/LP buckets to also add in).

**Structure:**
- **10% of category (45,000,000 KASH, 4.5% of total supply)** deposited directly
  into the on-chain `x/gov` community pool at genesis — immediately available,
  but only spendable via a passed governance proposal (and, once decision #14 is
  implemented, subject to that proposal's minimum 48-hour execution timelock
  before any approved spend actually moves funds).
- **Remaining 90% of category (405,000,000 KASH, 40.5% of total supply)** held
  in a dedicated, non-team-controlled vesting account. Releases in **32 equal
  quarterly tranches over 8 years**, first tranche at genesis+3mo, no cliff —
  each tranche ≈ **12,656,250 KASH** feeding into the community pool.
- Every tranche, once released into the pool, is still subject to the same
  per-spend governance-proposal gate as the genesis tranche — the vesting
  schedule controls how fast the pool *refills*, governance controls every
  actual *disbursement* out of it. No one can spend more than what's currently
  in the pool regardless of the total category size.
- Intended uses: ecosystem grants, developer incentive programs, liquidity
  incentives, public-goods funding, future incentivized-testnet or community
  airdrop programs — all governance-directed, not foundation-discretionary.
- Deliberately starts releasing earlier (genesis+3mo) than Team or Foundation,
  but each tranche is small (≈1.27% of total supply) and spend-gated, so an
  early start doesn't create a large-unlock clustering event the way a big
  single-day team/foundation cliff would.

*Injective and dYdX figures are the survey's "ecosystem + community + public"
combined totals; cited here only as an upper-bound sanity check, not an
apples-to-apples match.

---

### 2. Validator & Staking Incentives — 22% (220,000,000 KASH)

**Why this exists as a separate pool from protocol inflation:** the chain's mint
params are already locked at `inflation_min == inflation_max == 0.0001`
(`networks/mainnet/genesis-params.json`) — a flat 0.01%/year issuance that adds
roughly 0.1% to supply per decade. That's nowhere near enough on its own to fund
a competitive staking APY or attract a broad delegator base in the early years.
This pool is the real mechanism that does that job; it is functionally
equivalent to "pre-funded inflation" rather than a reward for any individual or
insider.

**Structure:**
- **No cliff** — starts streaming at genesis. Unlike Team or Foundation, this
  pool needs to start funding real rewards from day one, both to give delegators
  an actual reason to bond stake beyond the 10 initial validators' own
  self-delegations, and to support genuine decentralization of voting power
  quickly rather than after a year-long wait.
- **Streams linearly over 6 years** (72 months) directly into the staking
  distribution module — the same mechanism regular delegators already receive
  ordinary staking rewards through — averaging **≈36,666,667 KASH/year**
  (≈3,055,556 KASH/month).
- Critically: this pool **never sits in a liquid, individually-controlled
  wallet**. It moves module-account-to-module-account into the same
  distribution flow as protocol inflation. There is no step in this design
  where a person or small group holds this allocation as a spendable balance —
  which is precisely the "large wallet moved to an exchange" pattern flagged as
  a contributing factor in the MANTRA crash. That failure mode is structurally
  unavailable to this bucket by construction.
- The exact annual curve (flat vs. front-loaded/declining, à la Osmosis'
  "thirdening") is left to whoever owns emissions design — the total, duration,
  and delivery mechanism (module-to-module, not a wallet) are the load-bearing
  parts of this proposal; the precise year-by-year shape is a refinement, not a
  blocker.

---

### 3. Foundation Reserve — 16% (160,000,000 KASH)

**Why this carries the longest lockup horizon of any category:** "foundation
reserve" is historically the vaguest, most-discretionary allocation bucket
across every chain in the peer survey, and it's the bucket most directly
analogous to the pattern flagged in the MANTRA post-mortem — large, relatively
opaque wallet movements with no public schedule attached to them, which is what
made outside observers read pre-crash exchange inflows as probable insider
dumping rather than routine treasury management. This proposal's answer to that
specific risk is to make Foundation Reserve the *slowest bucket to ever become
liquid*, not the fastest.

**Structure:**
- **15-month cliff** (three months longer than Team's — see the staggering
  rationale in the [anti-concentration section](#how-this-design-avoids-the-terralunamantra-concentration-failure-mode) below), then
  **45-month linear vest**, reaching full liquidity at **genesis+60 months (5
  years)** — the longest total horizon of any category in this table.
- ≈**3,555,556 KASH/month** during the linear phase.
- Intended uses: operating runway, grants administration, legal/compliance
  costs, exchange/market-making relationships, and a reserve for un-forecast
  needs including security-incident response.
- **Transparency commitment (for whoever finalizes this):** once foundation
  wallet address(es) exist, they should be published and labeled publicly
  alongside this schedule, with committed periodic (e.g. quarterly) public
  reporting on spend — the specific mitigation for the "opaque wallet"
  ambiguity that made the MANTRA post-mortem contentious in the first place.
  No addresses exist yet, so none are included here.

---

### 4. Team / Core Contributors — 15% (150,000,000 KASH)

**Structure:**
- **12-month cliff**, then **36-month linear vest**, full liquidity at
  **genesis+48 months (4 years)**. ≈**4,166,667 KASH/month** during the linear
  phase.
- **Size-tiered extension, borrowed directly from Terra 2.0's own post-collapse
  redesign** (per the research: Terra's relaunch gave wallets under 1M LUNA a
  1yr cliff + 2yr vest, but wallets over 1M LUNA a 1yr cliff + **4yr** vest,
  specifically sizing vesting duration to holding size to blunt whale dumping).
  Applied here pre-emptively rather than after a collapse: **any single
  individual or entity's personal grant within this bucket that exceeds 1% of
  total supply (10,000,000 KASH) automatically extends to a 60-month (5-year)
  linear vest instead of the standard 36 months.** A larger personal grant is
  structurally required to unlock more slowly — this applies regardless of who
  holds it, with no discretionary override.
- **No acceleration on departure, acquisition, or other liquidity events**
  without a separate, explicit, governance-reviewed exception — the standard
  schedule continues on its original timeline regardless of employment status,
  removing any incentive to time a departure around an unlock.
- Team and Foundation carry deliberately similar (not identical, but close)
  terms — both use a ~1-year-scale cliff and a multi-year linear tail — rather
  than giving team members shorter lockups or friendlier terms than the
  foundation bucket, following the pattern the research flagged in Berachain's
  design (team and investors on identical schedules, no favorable insider
  terms).

---

### 5. Initial Validator Self-Delegation Bonds — 2% (20,000,000 KASH; 2,000,000 KASH × 10 validators)

**This is the one category that is genuinely not vested the same way the others
are** — and that's the correct call, not an oversight. Its purpose is
procedural (give each of the 10 initial validators, decision #16, real
skin-in-the-game capital to meet a genesis min-self-delegation requirement, on a
chain whose token literally doesn't exist yet for anyone to already hold before
genesis) rather than compensation, so it shouldn't be sized or vested like a
reward pool.

**Structure:**
- **2,000,000 KASH per validator, identical across all 10** — no initial
  validator receives a larger bonding allocation than another, so this
  allocation alone can never make any one validator's genesis-day bonded stake
  disproportionate to the rest of the initial cohort.
- **Immediately liquid and immediately self-bonded** via each validator's own
  `MsgCreateValidator` self-delegation. The moment it's bonded it is already
  subject to the chain's standard 21-day unbonding period (decision #10) if a
  validator ever chooses to unbond it — real structural friction against
  instant liquidity, delivered through the ordinary staking mechanism rather
  than a bespoke vesting contract.
- **Not a clawback** — unbonding it doesn't forfeit it; it's a genuine grant.
  The expectation that validators keep it bonded as an ongoing condition of
  remaining in the initial cohort is an operational/legal matter for a
  validator agreement, out of this document's scope — but any unbonding is
  publicly visible on-chain either way, which is itself a soft deterrent.
- Deliberately the smallest percentage of any bucket in this table (2%)
  precisely because its function is procedural bootstrapping, not reward or
  compensation — it shouldn't be sized like either of those.

---

## How this design avoids the Terra/LUNA & MANTRA concentration failure mode

This section exists because the team's own decisions doc cites the OM crash
explicitly ("avoid concentrated allocations, publish vesting schedule before
genesis not after"), and the research behind this proposal identified that
lesson as having two distinct, specific mechanisms — not a generic "be careful"
warning. Here is how each specific mechanism is addressed, point by point:

**1. Terra's original design combined 56% insider concentration with short
(3-18 month) investor lockups.** This proposal's combined Team + Foundation
allocation is **31% of total supply** — 25 points below Terra's original 56%,
and below even the low end of the modern peer-chain range (40-53%) the research
survey found, despite this design having *no separate investor tranche at all*
to further inflate that number (ArkConstellation, as a fork with no announced
private raise, doesn't carry the extra 20-35% "investors" bucket that peer
chains like Celestia, Sei, and Berachain layer on top of their team allocation).
And unlike Terra's shortest lockup (3 months + 6-month linear on the private
round), **zero tokens in either the Team or Foundation bucket are liquid before
month 12 at the earliest** — both categories carry cliffs at or above the "1
year minimum, zero exceptions" pattern the research found across every
non-fair-launch peer chain surveyed.

**2. Terra 2.0's own fix — size-tiered vesting — is applied here pre-emptively.**
The Team bucket's >1%-of-supply grants automatically extend to a 5-year vest
instead of 3 years, directly mirroring the mechanism Terra itself adopted only
*after* its collapse (large wallets vest slower, regardless of category).

**3. MANTRA's failure was concentration + low float + opaque large-wallet
movement, not an algorithmic mechanism.** Top-10 OM wallets held ~53% of supply
at crash time; this design's genesis-day maximum private (non-protocol) holding
is **0.2%** (one validator's self-delegation) — see the
[liquidity snapshot](#genesis-day-liquidity-snapshot) table above for the full
comparison. Total genesis-day liquid/bondable float across every category is
**at most 6.5% of supply**, and 4.5 of those points sit in a protocol-owned,
governance-gated community pool rather than any private wallet — the opposite
of MANTRA's thin-liquid-float-under-a-large-illiquid-overhang structure, because
here the overhang (the other 93.5%) is on a published, time-gated release
schedule from day one rather than an undisclosed future unlock.

**4. MANTRA's most-criticized ambiguity was undisclosed large-wallet-to-exchange
movement ahead of a scheduled unlock.** This document is written specifically
to be publishable *before* genesis, not after — the team's own stated lesson.
It contains no real wallet addresses because none exist yet; the explicit
recommendation ([Foundation section](#3-foundation-reserve--16-160000000-kash))
is that once they do exist, they get published and labeled alongside this
schedule, removing the specific ambiguity ("is this routine treasury management
or insider dumping?") that made the MANTRA post-mortem contentious.

**5. Celestia's cautionary note — even a reasonable multi-year vest can still
cluster a large single-day unlock (~17% of supply on one date).** Team (12mo
cliff) and Foundation (15mo cliff) are deliberately offset by a full quarter so
their cliffs, and their monthly unlock dates thereafter, never land on the same
calendar date. Community-pool quarterly tranches start earlier (+3mo) but are
individually small (≈1.27% of supply each) and spend-gated by governance, so an
incidental date overlap with a Team or Foundation tranche would not itself
create a large-unlock clustering event the way two full annual insider tranches
landing on the same day would.

**6. Validator & Staking Incentives — the one large (22%) bucket with no
cliff — is structurally exempt from the "large wallet" risk by design, not by
trust.** It streams module-to-module directly into the same distribution
mechanism ordinary delegators already receive rewards through. There is no
point in its lifecycle where it exists as a liquid balance a person or small
group could move to an exchange, which is exactly the pattern flagged in the
MANTRA pre-crash wallet analysis.

**7. Governance disbursements are intended to inherit the same "give the market
time to react" principle the decisions doc already requires for governance
execution generally** (decision #14, minimum 48-hour timelock — not yet
implemented anywhere in the codebase, see `GAPS.md`). Every community-pool
spend and any future governance-driven change to this schedule should run
through that same delay once it exists — a different mechanism than MANTRA's
weekend-liquidity-crunch scenario, but addressing the same underlying gap: no
large, consequential on-chain action should be able to execute with zero
warning.

---

## What this does not resolve

1. **The total supply figure itself is still an unapproved proposal.** Every
   amount in this document is computed against
   [`total-supply-proposal.md`](./total-supply-proposal.md)'s recommended 1B
   KASH, which has not been signed off. If that number changes, every KASH
   figure here needs to be recomputed — the percentages and structural design
   (cliffs, durations, the 45,000,000 KASH concentration ceiling logic, etc.)
   are the parts intended to survive a total-supply change; the absolute
   numbers are not.
2. **No wallet addresses exist and none are proposed here.** The admin/upgrade
   multisig (decision #17) and any team/foundation/validator wallet addresses
   are separate, pending decisions this document deliberately does not touch.
3. **The 48-hour governance execution timelock (decision #14) is still
   unimplemented.** This proposal's reasoning leans on that timelock existing
   for governance-directed community-pool spends and any future schedule
   changes — it does not exist in the codebase yet (`GAPS.md` confirms: "stock
   cosmos-sdk `x/gov` has no such mechanism... not started"). This proposal
   does not implement it; it only assumes it will exist by the time these
   disbursement mechanisms go live.
4. **Decision #15 (min governance deposit)** can now be computed against a
   real total once one is adopted, but still needs its own explicit figure and
   sign-off — not addressed by this document.
5. **The exact annual emissions curve for Validator & Staking Incentives**
   (flat linear vs. front-loaded/declining) is left as an open refinement for
   whoever owns emissions design — the total, the 6-year duration, and the
   module-to-module (never-a-wallet) delivery mechanism are what this proposal
   is actually recommending; the precise year-by-year shape is not load-bearing
   to the anti-concentration argument above.
6. **Legal, tax, and jurisdiction-specific structuring** of the Team and
   Foundation vesting (e.g., whether vesting runs through an actual smart
   contract / vesting module vs. an off-chain legal agreement with an on-chain
   mirror, entity structuring, securities-law treatment) is entirely out of
   scope — this document proposes the economic schedule only, not its legal
   implementation.

---

## Sign-off

This table is a recommendation, not a decision. Please mark below (or in the
decisions doc directly) once reviewed:

- [ ] Approved as proposed — 45% / 22% / 16% / 15% / 2% split and vesting
      structures as written
- [ ] Approved with modification — specify category, number, and reasoning
- [ ] Rejected — specify concern

Once approved (and only once `total-supply-proposal.md` is also approved, since
this table's amounts depend on it), update
`docs/decisions/module-and-config-decisions.md`'s Token Distribution section and
decision #15 to reference these figures, and remove the "PROPOSAL" framing from
this document or fold it into the decisions doc directly.
