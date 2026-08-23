package main

import (
	"fmt"
	"os"

	clienthelpers "cosmossdk.io/client/v2/helpers"
	wasmtypes "github.com/CosmWasm/wasmd/x/wasm/types"
	"github.com/MANTRA-Chain/mantrachain/v8/app"
	"github.com/MANTRA-Chain/mantrachain/v8/cmd/arkd/cmd"
	svrcmd "github.com/cosmos/cosmos-sdk/server/cmd"
	sdk "github.com/cosmos/cosmos-sdk/types"
	evmcfg "github.com/cosmos/evm/config"
)

func main() {
	sdk.SetCoinDenomRegex(ArkCoinDenomRegex)
	setupConfig()
	rootCmd := cmd.NewRootCmd()
	if err := svrcmd.Execute(rootCmd, clienthelpers.EnvPrefix, app.DefaultNodeHome); err != nil {
		fmt.Fprintln(rootCmd.OutOrStderr(), err)
		os.Exit(1)
	}
}

// Denom naming (bech32 prefix + base denom) locked as an explicit Day-1 decision -
// see docs/decisions/module-and-config-decisions.md and STATUS.md. Previously
// inherited from MANTRA-Chain ("mantra"/"amantra"); Ark uses its own identity
// throughout so nothing here leaks the fork's origin into addresses or the
// native token.
//
// Denom layout follows docs/decisions/module-and-config-decisions.md (Ethereum parity):
//
//	esp   = smallest/base unit (exponent 0, 1 wei equivalent, used for staking/bonding)
//	espees = intermediate unit (exponent 9, 1 gwei equivalent)
//	KASH  = display/EVM unit (exponent 18, 1 ether equivalent)
const (
	HumanCoinUnit = "KASH"
	BaseCoinUnit  = "esp"
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

// ArkCoinDenomRegex returns the coin denom regex string used to override the
// default SDK coin denom regex (needed since "KASH" would otherwise be
// rejected by the SDK's default, stricter denom pattern).
func ArkCoinDenomRegex() string {
	return `[a-zA-Z][a-zA-Z0-9/:._-]{1,127}`
}

func setupConfig() {
	// set the address prefixes
	config := sdk.GetConfig()
	SetAddressPrefixes(config)
	evmcfg.SetBip44CoinType(config)
	config.Seal()
}

// SetAddressPrefixes builds the Config with Bech32 addressPrefix and publKeyPrefix for accounts, validators, and consensus nodes and verifies that addreeses have correct format.
func SetAddressPrefixes(config *sdk.Config) {
	config.SetBech32PrefixForAccount(Bech32Prefix, Bech32PrefixAccPub)
	config.SetBech32PrefixForValidator(Bech32PrefixValAddr, Bech32PrefixValPub)
	config.SetBech32PrefixForConsensusNode(Bech32PrefixConsAddr, Bech32PrefixConsPub)
	config.SetAddressVerifier(wasmtypes.VerifyAddressLen())
}
