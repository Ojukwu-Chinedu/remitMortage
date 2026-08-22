package app

import "encoding/json"

// GenesisState of the blockchain is represented here as a map of raw json
// messages key'd by a identifier string.
// The identifier is used to determine which module genesis information belongs
// to so it may be appropriately routed during init chain.
// Within this application default genesis information is retrieved from
// the ModuleBasicManager which populates json from each BasicModule
// object provided to it during init.
type GenesisState map[string]json.RawMessage

// FeeDenom is Ark's native base denomination (18 decimals) - see
// cmd/mantrachaind/main.go's BaseCoinUnit, which this must stay in sync with.
var FeeDenom = "espees"

// Deliberately no NewDefaultGenesisState() here. A previous version of this
// file defined one, intended to wire FeeDenom into the evm/erc20/feemarket
// app_state automatically whenever `mantrachaind init` runs - but it was
// never actually called from cmd/ (verified: grepped the whole tree, only
// this file's own definition matched), so none of that wiring ever ran in
// practice. It was also broken even if it had been wired in:
// erc20types.DefaultGenesisState() always returns an empty TokenPairs slice
// (see the vendored cosmos/evm fork's x/erc20/types/genesis.go), so
// `erc20State.TokenPairs[0].Denom = FeeDenom` would have panicked on index 0
// of an empty slice the first time `mantrachaind init` actually ran it.
//
// Genesis-time denom/erc20/feemarket customization (including the
// bank.denom_metadata entry the evm module's InitGenesis requires, which
// this removed function never set either) is instead handled by the
// deployment-time genesis-merge-patch process documented in
// networks/devnet/README.md and networks/mainnet/RUNBOOK.md - that is
// tested, versioned, and reviewable, unlike a hardcoded value baked into
// the binary's init path. `mantrachaind init`'s raw output should be
// treated as generic SDK/EVM defaults, not a finished genesis.
