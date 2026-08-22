# Mainnet genesis day — operator runbook

One-shot, in order. This pipeline runs once for real — if a step's
prerequisite isn't met, stop and fix it before proceeding; every script
here fails loudly rather than silently on bad input, so a hard stop is the
expected/safe outcome of a real problem, not something to route around.

**Before starting**, confirm all of these are actually true — do not take
any on faith:

- [ ] Eng 1 has tagged the frozen binary (`v1.0.0` per `CONTRIBUTING.md`'s
      versioning table) and its CI-published SHA-256 is recorded somewhere
      independent of this repo (e.g. pinned in the genesis coordination
      channel).
- [ ] `CONTRIBUTING.md`'s "Key Decisions" checklist is fully resolved —
      chain-id, native token allocations, `x/tax`/`x/tokenfactory`/
      `x/sanction` keep-or-strip, initial validator identities. If any box
      is still open, stop — do not improvise a value here.
- [ ] Eng 3's chaos/security sign-off has actually landed (required before
      mainnet genesis per `CONTRIBUTING.md`).
- [ ] Every prospective validator has been sent
      `networks/mainnet/genesis-params.json` and the account-allocation
      list, and has confirmed their intended self-delegation amount and
      moniker.

## Step 1 — Assemble the base genesis

```bash
BIN=./build/mantrachaind     # the tagged v1.0.0 binary, not a local rebuild
CHAIN_ID=<final chain-id>    # from the locked Day-1 decision, not devnet's

$BIN init <moniker> --chain-id "$CHAIN_ID" --home /tmp/mainnet-genesis

# Add every real, decided allocation - the exchange/foundation/team/
# ecosystem accounts from the locked allocation list, AND every
# prospective validator's self-delegation funding account. A validator
# whose account isn't funded here will be rejected in Step 2, correctly.
$BIN genesis add-genesis-account <address> <amount>aesp --home /tmp/mainnet-genesis
# aesp is the base unit, KASH is the 18-decimal display (1 KASH = 1 followed by 18 zeros aesp). This is
# the codebase's CURRENT denom (app/params/config.go) - CONTRIBUTING.md still
# lists "native token name, symbol, and initial allocations" as an open
# Day-1 decision, so confirm this hasn't changed before running for real.
# ... repeat for every account ...

python3 -c "
import json
g = json.load(open('/tmp/mainnet-genesis/config/genesis.json'))
patch = json.load(open('networks/mainnet/genesis-params.json'))
patch.pop('_comment', None)
# REQUIRED, not optional: the evm module's InitGenesis panics at node
# startup without a bank.denom_metadata entry for the bond/mint/evm denom
# ('error initializing evm coin info: denom metadata <denom> could not be
# found') - discovered empirically standing up the devnet, see
# networks/devnet/genesis-template.json's _comment for the full story.
# The denom_metadata below must match whatever denom actually ended up
# in genesis-params.json above (aesp base, KASH display).
patch.setdefault('app_state', {}).setdefault('bank', {})['denom_metadata'] = [{
    'description': 'The native staking and governance token.',
    'denom_units': [{'denom': 'aesp', 'exponent': 0}, {'denom': 'esp', 'exponent': 12}, {'denom': 'KASH', 'exponent': 18}],
    'base': 'aesp', 'display': 'KASH', 'name': 'KASH', 'symbol': 'KASH',
}]
def merge(a, b):
    for k, v in b.items():
        if isinstance(v, dict) and isinstance(a.get(k), dict): merge(a[k], v)
        else: a[k] = v
merge(g, patch)
json.dump(g, open('/tmp/mainnet-genesis/config/genesis.json', 'w'))
"
$BIN genesis validate-genesis /tmp/mainnet-genesis/config/genesis.json
cp /tmp/mainnet-genesis/config/genesis.json networks/mainnet/base-genesis.json
```

`validate-genesis` only checks structural/proto validity - it will NOT catch
a missing `denom_metadata` entry (that's a runtime panic during `InitChain`,
not a static validation error). Before trusting this base genesis, do a
throwaway single-node boot smoke test and confirm it reaches height 1
without panicking:

```bash
rm -rf /tmp/smoke-test
$BIN init smoketest --chain-id "$CHAIN_ID" --home /tmp/smoke-test >/dev/null
cp networks/mainnet/base-genesis.json /tmp/smoke-test/config/genesis.json
timeout 10 $BIN start --home /tmp/smoke-test --minimum-gas-prices 0aesp || true
# look for "committed state" / height advancing in the output above, not a panic
```

If `genesis-params.json` needs a real value for something left as a
devnet-only placeholder in this repo (`x/tax.mca_address`,
`x/tokenfactory.fee_collector_address` — see that file's header comment),
resolve it now, before continuing. Do not carry a devnet placeholder
address into this file.

## Step 2 — Collect and validate gentxs

Each validator submits their `gentx-<moniker>.json` through the agreed
secure channel (not a public PR — see `SECURITY.md`) into a single
directory.

```bash
MANTRACHAIND_BIN=$BIN ./scripts/genesis/collect-gentx.sh \
  <gentx-submissions-dir> \
  networks/mainnet/base-genesis.json \
  networks/mainnet/genesis-template.json
```

Read the output carefully. Every `REJECT` line names the file and the
specific reason. **Do not proceed with a partial validator set** — resolve
each rejection with its submitter (resubmit, or explicitly agree to
exclude them) and re-run this step from scratch until it exits 0.

## Step 3 — Hash and cross-publish

```bash
./scripts/genesis/hash-genesis.sh networks/mainnet/genesis-template.json
```

Publish the **canonical** hash (not the raw-bytes one — see the script's
output for why) to every validator through the agreed channel. Every
validator independently runs this same command against the file you send
them and confirms the hash matches before going further. A single
mismatch means stop and find out why before any node starts.

## Step 4 — Commit and tag

```bash
cp networks/mainnet/genesis-template.json networks/mainnet/genesis.json
git add networks/mainnet/genesis.json
git commit -m "genesis: canonical mainnet genesis, hash <canonical hash from step 3>"
```

Open a PR per `CONTRIBUTING.md`'s branch rules (never push directly to
`base-genesis` or `main`) even under time pressure — the "track lead sign
off before merge" requirement exists specifically for this file.

## Step 5 — Coordinated start

All validators start their nodes at the agreed genesis time
(`genesis_time` in the file — everyone is starting the *same* file, so
this is already fixed). Confirm with each validator that
`mantrachaind genesis validate-genesis` passed locally on their copy
before they start.

## If something goes wrong after nodes start

This runbook covers assembly, not incident response — halts, recovery,
and the key ceremony process live in `ops/runbooks/` (Eng 4's track). If
the chain fails to reach block 1, the most likely causes, in order of
probability based on what this pipeline already checked: a validator
started with a genesis file that doesn't match the published hash (go
back to Step 3), or a gentx that passed `collect-gentx.sh`'s checks here
but still fails differently under the *tagged binary* if it differs from
what was used to build `networks/mainnet/base-genesis.json` in Step 1
(always use the same tagged binary for every step of this runbook).
