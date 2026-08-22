package types

import (
	"strings"

	errorsmod "cosmossdk.io/errors"
	sdk "github.com/cosmos/cosmos-sdk/types"
	sdkerrors "github.com/cosmos/cosmos-sdk/types/errors"
	ethcommon "github.com/ethereum/go-ethereum/common"
)

func validateBlacklistMessage(authority string, accounts []string) error {
	if _, err := sdk.AccAddressFromBech32(authority); err != nil {
		return errorsmod.Wrapf(sdkerrors.ErrInvalidAddress, "invalid authority address (%s)", err)
	}

	if len(accounts) == 0 {
		return errorsmod.Wrap(sdkerrors.ErrInvalidRequest, "accounts list cannot be empty")
	}

	for _, account := range accounts {
		if strings.HasPrefix(account, "0x") || strings.HasPrefix(account, "0X") {
			if !ethcommon.IsHexAddress(account) {
				return errorsmod.Wrapf(sdkerrors.ErrInvalidAddress, "invalid hex account address: %s", account)
			}
		} else {
			if _, err := sdk.AccAddressFromBech32(account); err != nil {
				return errorsmod.Wrapf(sdkerrors.ErrInvalidAddress, "invalid account address: %s", account)
			}
		}
	}

	return nil
}
