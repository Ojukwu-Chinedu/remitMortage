package distrclaim

import (
	"math/big"
	"testing"

	cmn "github.com/cosmos/evm/precompiles/common"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/vm"
	"github.com/stretchr/testify/require"

	sdk "github.com/cosmos/cosmos-sdk/types"
)

func TestEmitClaimRewardsAndConvertCoinEvent_NilChecks(t *testing.T) {
	p := &Precompile{
		Precompile: cmn.Precompile{
			ContractAddress: common.HexToAddress(DistributionClaimPrecompileAddress),
		},
	}
	ctx := sdk.Context{}
	delegator := common.HexToAddress("0x1111111111111111111111111111111111111111")
	amount := big.NewInt(1000)

	// 1. evm == nil
	err := p.emitClaimRewardsAndConvertCoinEvent(ctx, nil, delegator, "esp", amount)
	require.NoError(t, err)

	// 2. evm.StateDB == nil
	evmWithoutStateDB := &vm.EVM{}
	err = p.emitClaimRewardsAndConvertCoinEvent(ctx, evmWithoutStateDB, delegator, "esp", amount)
	require.NoError(t, err)
}

func TestTopicAddress(t *testing.T) {
	addr := common.HexToAddress("0x1234567890abcdef1234567890abcdef12345678")
	topic := topicAddress(addr)
	require.Equal(t, addr.Bytes(), topic.Bytes()[12:])
}
