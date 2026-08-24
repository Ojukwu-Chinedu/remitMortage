# PROPOSAL: ArkConstellation (KASH) Genesis Total Supply

**Status:** 🟠 PROPOSAL — not decided, not locked. Requires explicit sign-off from whoever owns decision #15 / the Token Distribution section of `docs/decisions/module-and-config-decisions.md` before it can be treated as the figure engineering builds against.

**Author:** Drafted for review, 2026-08-24.

**Scope:** This proposal addresses exactly one number — the genesis-day total supply of KASH. It does **not** propose an allocation/vesting table (that is a separate, still-open item) and it does **not** touch the governance execution timelock gap (also separate and still unimplemented). Adopting a number here unblocks those two items' *math* without resolving either of them on its own. See "What this does not resolve" below.

---

## Recommendation

> ## **1,000,000,000 KASH (one billion)** as the fixed genesis-day total supply.

In base units, that is 1,000,000,000 × 10¹⁸ `esp` = **1,000,000,000,000,000,000,000,000,000 `esp`** (10²⁷ `esp`; equivalently 1,000,000,000,000,000,000 `espees`).

This is proposed as the number that goes into `networks/mainnet/genesis-params.json` / the genesis account allocations, once the allocation table (separately blocked) is populated to sum to it.

---

## Why this number

### 1. It's the strongest peer-convergence point in the survey

Of the nine chains researched, **five cluster at or near the 1B order of magnitude**: Osmosis (1,000,000,000 cap), Celestia (1,000,000,000 genesis supply), Story Protocol (1,000,000,000 cap), dYdX Chain (1,000,000,000 total), and Kava (1,080,000,000 fixed cap — same order of magnitude, effectively the same design point). No other figure in the cohort — not Injective's 100M, not Sei's 10B — has anywhere near that level of agreement across independent teams making independent choices. When five separate design teams converge on the same order of magnitude, that's meaningful evidence about what reads as "normal" to exchanges, wallets, auditors, and users evaluating a new Cosmos L1 in 2026, even though (per the research) the number itself carries no economic content on its own.

### 2. ArkConstellation's mint parameters make this a de facto permanent-supply decision, not just a starting point — which changes which peers are the right analogy

This is the load-bearing point that the standard "genesis supply" framing from most of the peer research doesn't quite capture, and it's worth stating explicitly: with `inflation_min == inflation_max == 0.0001` (a flat 0.01%/year issuance rate that does not respond to bonded ratio, since `goal_bonded` only matters when there's a min/max band to move within), **KASH's supply trajectory is essentially flat for the practical life of the chain**. Compounding 0.01%/year for a decade adds roughly 0.1% to total supply; for a century, roughly 1%. That's noise, not a growth curve.

That means ArkConstellation is not analogous to Osmosis (asymptotically growing toward 1B over years via a declining-but-real emissions schedule) or to Injective/Cosmos Hub (wide bonded-ratio bands moving supply meaningfully year to year). It is structurally much closer to **Kava** (fixed 1.08B cap, genuinely zero inflation since Jan 2024) and to the *effective* behavior of **Sei** (10B hard-capped pre-mint) and **Story** (1B hard cap, vesting-gated release) — chains where the number set at or near genesis **is**, for all practical purposes, the number forever, absent a deliberate future governance action. The team should evaluate this proposal with that weight, not with the lighter "we can always let inflation reshape this over time" assumption that applies to Osmosis- or Injective-style chains.

Practically, this means: whatever total is picked here should be picked as if it's permanent, because under the current mint configuration, it functionally is.

### 3. A round, fixed, disclosed figure is the direct opposite of the survey's clearest cautionary tale

Evmos — the closest architectural precedent to ArkConstellation in the survey (Cosmos SDK + EVM) — combined an uncapped supply with an implementation bug that let realized inflation overshoot its announced schedule by roughly 4x, and the token never recovered. ArkConstellation's mint params already prevent that specific failure mode structurally (the band is pinned, not wide), but choosing a clean, round, publicly-disclosed genesis total reinforces the same discipline the team's own decisions doc invokes when it cites the Terra/LUNA collapse: a number that's simple to state, simple to audit, and hard to quietly walk back later.

### 4. It gives the (separately blocked) allocation table room to work with round numbers

Once someone drafts the Team / Foundation / Validator / Community vesting table (decision doc's open "Token Distribution" section), they'll be assigning percentages against whatever total is set. 1,000,000,000 is large enough that typical allocation slices (e.g., a 10-validator initial cohort's self-bonds, a community-pool percentage, individual team vesting tranches) land on clean whole-KASH numbers without forcing fractional-KASH grants — a real usability concern at smaller totals like 100M once you're slicing it ten-plus ways.

### 5. It's consistent with (and unblocks) the placeholder already sitting in the codebase

`networks/mainnet/genesis-params.json`'s `gov.min_deposit` is currently a flagged placeholder — `88,888 KASH` regular / `888,888 KASH` expedited — explicitly waiting on decision #15's "total supply not yet defined" blocker. Against a 1,000,000,000 KASH total, those placeholders already sit at a plausible ~0.0089% / ~0.0889% of supply, which is a sane order of magnitude for an anti-spam deposit (high enough to deter spam, low enough for real participants). That's a sanity check in this proposal's favor, not a claim that decision #15 is resolved — it still needs its own explicit sign-off once a total is adopted.

---

## Alternates considered

### Alternate A — 100,000,000 KASH (Injective-style scarcity)

**The case for it:** Injective launched with exactly this figure and it's the strongest "prestige/scarcity" precedent in the cohort — a smaller denominator produces a higher nominal per-unit price at any given market cap, which some teams and communities read as a stronger signal than a large supply with a proportionally lower unit price. It also keeps whole-KASH accounting simple for large treasury-level transfers.

**The tradeoff against it:** Injective's scarcity story is *actively maintained* — it stays net-deflationary primarily through weekly burn auctions (60% of dApp fee revenue) layered on top of its bonded-ratio mint, and it just passed a governance vote (IIP-617, Jan 2026) to double that deflation rate further. ArkConstellation has no equivalent burn mechanism in its current design, and its mint band is pinned flat rather than dynamic. Without a structural deflationary lever, "start smaller" here doesn't carry the same ongoing scarcity narrative Injective earns through continuous action — it would just be a smaller fixed number, sitting furthest from the survey's peer cluster.

### Alternate B — 10,000,000,000 KASH (Sei-style low unit price)

**The case for it:** Sei deliberately chose a 10B hard cap specifically to keep the per-token price low (cents rather than dollars) at typical early-L1 market caps, which can read as more approachable/affordable to retail participants and gives allocation designers more room to hand out clean whole-KASH grants at very fine granularity (e.g., small community/testnet incentive awards) without touching fractional units.

**The tradeoff against it:** A 10B figure sits an order of magnitude above the survey's clearest convergence point and would make ArkConstellation the largest nominal supply in the entire cohort except Sei itself. "Low unit price" cuts both ways psychologically — it can read as approachable, but it can equally read as "diluted" or "cheap" to observers who (rightly or wrongly) associate a large digit-count with a low-value token, independent of actual market cap. Given the mint band means this number is effectively permanent (see reasoning point 2), that psychology, once set, isn't easily revisited.

**Recommendation stands at 1,000,000,000 KASH** as the point that best balances peer convergence, allocation-table usability, and avoiding either alternate's more idiosyncratic tradeoff.

---

## What this does not resolve

Adopting a total-supply figure here is a necessary input to, but not a substitute for, the other two items the decisions doc flags as still blocking mainnet genesis parameterization:

1. **The genesis allocation/vesting table** (Team / Foundation / Validator incentives / Community — currently all blank in the decisions doc's "Token Distribution" section) still needs to be drafted and separately approved. This proposal only supplies the denominator that table's percentages will sum against; it says nothing about how the pie should be sliced or vested. The team's own cited lesson from the OM/LUNA crash — "avoid concentrated allocations, publish vesting schedule before genesis not after" — applies entirely to that table, not to this number.
2. **The 48-hour-minimum governance execution timelock** (decision #14) remains unimplemented in the codebase — stock `x/gov` has no such mechanism, and nothing in this proposal changes that. It is an engineering task independent of the supply figure.
3. **Decision #15 (min governance deposit)** can now be computed proportionally against this total once it's adopted, but still needs its own explicit sign-off and a deliberate choice of target percentage — this proposal only shows that the existing placeholder happens to already be in a plausible range, not that it's approved.

---

## Sign-off

This number is a recommendation, not a decision. Please mark below (or in the decisions doc directly) once reviewed:

- [ ] Approved as proposed — 1,000,000,000 KASH
- [ ] Approved with modification — specify number and reasoning
- [ ] Rejected — specify concern

Once approved, update `docs/decisions/module-and-config-decisions.md`'s Token Distribution section and decision #15 to reference this figure, and remove the "PROPOSAL" framing from this document or fold it into the decisions doc directly.
