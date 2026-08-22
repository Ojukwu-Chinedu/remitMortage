package params

import (
	wasmtypes "github.com/CosmWasm/wasmd/x/wasm/types"
	sdk "github.com/cosmos/cosmos-sdk/types"
)

// Kept in sync with cmd/mantrachaind/main.go's identical constants - that file's
// setupConfig() is what actually seals the SDK config (this package's own
// SetAddressPrefixes() below intentionally does not call Seal(), so it never
// conflicts with main's later call), but both are kept consistent to avoid a
// stale duplicate definition drifting from the real one.
const (
	HumanCoinUnit = "espees"
	BaseCoinUnit  = "aespees"
	ArkExponent   = 18

	DefaultBondDenom = BaseCoinUnit
)

var (
	Bech32Prefix = "ark"
	// Bech32PrefixAccPub defines the Bech32 prefix of an account's public key.
	Bech32PrefixAccPub = Bech32Prefix + "pub"
	// Bech32PrefixValAddr defines the Bech32 prefix of a validator's operator address.
	Bech32PrefixValAddr = Bech32Prefix + "valoper"
	// Bech32PrefixValPub defines the Bech32 prefix of a validator's operator public key.
	Bech32PrefixValPub = Bech32Prefix + "valoperpub"
	// Bech32PrefixConsAddr defines the Bech32 prefix of a consensus node address.
	Bech32PrefixConsAddr = Bech32Prefix + "valcons"
	// Bech32PrefixConsPub defines the Bech32 prefix of a consensus node public key.
	Bech32PrefixConsPub = Bech32Prefix + "valconspub"
)

func init() {
	sdk.SetCoinDenomRegex(ArkCoinDenomRegex)
	SetAddressPrefixes()
}

// ArkCoinDenomRegex returns the coin denom regex string
// this is used to override the default sdk coin denom regex
func ArkCoinDenomRegex() string {
	return `[a-zA-Z][a-zA-Z0-9/:._-]{1,127}`
}

// SetAddressPrefixes builds the Config with Bech32 addressPrefix and pubKeyPrefix for accounts, validators, and consensus nodes and verifies that addresses have correct format.
func SetAddressPrefixes() {
	config := sdk.GetConfig()
	config.SetBech32PrefixForAccount(Bech32Prefix, Bech32PrefixAccPub)
	config.SetBech32PrefixForValidator(Bech32PrefixValAddr, Bech32PrefixValPub)
	config.SetBech32PrefixForConsensusNode(Bech32PrefixConsAddr, Bech32PrefixConsPub)
	config.SetAddressVerifier(wasmtypes.VerifyAddressLen())
	// Deliberately does NOT call config.Seal() here - cmd/mantrachaind/main.go's
	// setupConfig() runs after this package's init() and seals the config itself.
	// Sealing here first would panic on main's subsequent Set* calls.
}
