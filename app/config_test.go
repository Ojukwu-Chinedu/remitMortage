package app_test

import (
	"testing"

	"github.com/MANTRA-Chain/mantrachain/v8/app"
	"github.com/stretchr/testify/require"
)

func TestParseChainID(t *testing.T) {
	testCases := []struct {
		name      string
		chainID   string
		expectID  uint64
		expectErr bool
	}{
		{
			name:      "Ark mainnet Cosmos format",
			chainID:   "arkconstellation-1",
			expectID:  11199,
			expectErr: false,
		},
		{
			name:      "Ark devnet format",
			chainID:   "arkdevnet_9000-1",
			expectID:  9000,
			expectErr: false,
		},
		{
			name:      "Ark EVM standard format",
			chainID:   "ark_11199-1",
			expectID:  11199,
			expectErr: false,
		},
		{
			name:      "Legacy MANTRA mainnet",
			chainID:   "mantra-1",
			expectID:  5888,
			expectErr: false,
		},
		{
			name:      "Legacy MANTRA testnet",
			chainID:   "mantra-dukong-1",
			expectID:  5887,
			expectErr: false,
		},
		{
			name:      "Generic EIP-155 chain ID string",
			chainID:   "custom_12345-2",
			expectID:  12345,
			expectErr: false,
		},
		{
			name:      "Large 64-bit unsigned chain ID beyond int32",
			chainID:   "large_42949672950-1",
			expectID:  42949672950,
			expectErr: false,
		},
		{
			name:      "Max uint64 chain ID representation",
			chainID:   "max_18446744073709551615-1",
			expectID:  18446744073709551615,
			expectErr: false,
		},
		{
			name:      "Overflowing uint64 value",
			chainID:   "overflow_18446744073709551616-1",
			expectID:  0,
			expectErr: true,
		},
		{
			name:      "Invalid chain ID format",
			chainID:   "invalid-chain-no-number",
			expectID:  0,
			expectErr: true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			id, err := app.ParseChainID(tc.chainID)
			if tc.expectErr {
				require.Error(t, err)
			} else {
				require.NoError(t, err)
				require.Equal(t, tc.expectID, id)
			}
		})
	}
}
