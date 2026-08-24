package app

import (
	erc20types "github.com/cosmos/evm/x/erc20/types"
)

// WTokenContractMainnet is the WrappedToken contract address for mainnet
const WTokenContractMainnet = "0x0000000000000000000000000000000000000000"

// ExampleTokenPairs creates a slice of token pairs, that contains a pair for the native denom of the example chain
// implementation.
var ExampleTokenPairs = []erc20types.TokenPair{
	{
		Erc20Address:  WTokenContractMainnet,
		Denom:         FeeDenom,
		Enabled:       true,
		ContractOwner: erc20types.OWNER_MODULE,
	},
}
