// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Precompile Interfaces & Security Audit Harness
 * @notice Formal Solidity definitions for all 10 enabled cosmos/evm & ArkConstellation precompiles.
 */

// 1. Bech32 Precompile (0x0000000000000000000000000000000000000400)
interface IBech32 {
    function hexToBech32(address addr, string memory prefix) external pure returns (string memory bech32Address);
    function bech32ToHex(string memory bech32Address) external pure returns (address addr);
}

// 2. Bank Precompile (0x0000000000000000000000000000000000000804)
interface IBank {
    function send(string memory toAddress, string memory denom, uint256 amount) external returns (bool success);
    function balanceOf(string memory account, string memory denom) external view returns (uint256 balance);
}

// 3. Staking Precompile (0x0000000000000000000000000000000000000800)
interface IStaking {
    function delegate(string memory validatorAddress, uint256 amount) external returns (bool success);
    function undelegate(string memory validatorAddress, uint256 amount) external returns (int64 completionTime);
    function redelegate(string memory srcValidatorAddress, string memory dstValidatorAddress, uint256 amount) external returns (int64 completionTime);
    function delegation(string memory validatorAddress, string memory delegatorAddress) external view returns (uint256 shares, uint256 balance);
}

// 4. Distribution Precompile (0x0000000000000000000000000000000000000801)
interface IDistribution {
    function setWithdrawAddress(string memory withdrawAddress) external returns (bool success);
    function withdrawDelegatorReward(string memory validatorAddress) external returns (uint256[] memory amounts, string[] memory denoms);
    function withdrawValidatorCommission() external returns (uint256[] memory amounts, string[] memory denoms);
}

// 5. ICS20 Precompile (0x0000000000000000000000000000000000000802)
interface IICS20 {
    function transfer(
        string memory sourcePort,
        string memory sourceChannel,
        string memory denom,
        uint256 amount,
        string memory sender,
        string memory receiver,
        uint64 timeoutHeightRevisionNumber,
        uint64 timeoutHeightRevisionHeight,
        uint64 timeoutTimestamp,
        string memory memo
    ) external returns (uint64 sequence);
}

// 6. Gov Precompile (0x0000000000000000000000000000000000000805)
interface IGov {
    function vote(uint64 proposalId, int32 option, string memory metadata) external returns (bool success);
    function voteWeighted(uint64 proposalId, int32[] memory options, uint256[] memory weights, string memory metadata) external returns (bool success);
}

// 7. Vesting Precompile (0x0000000000000000000000000000000000000803)
interface IVesting {
    function createClawbackVestingAccount(
        string memory fromAddress,
        string memory toAddress,
        int64 startTime,
        uint64[] memory lockupPeriods,
        uint64[] memory vestingPeriods,
        bool merge
    ) external returns (bool success);
}

// 8. Slashing Precompile (0x0000000000000000000000000000000000000806)
interface ISlashing {
    function unjail(string memory validatorAddress) external returns (bool success);
}

// 9. P256 Precompile (0x0000000000000000000000000000000000000100) - RIP-7212
interface IP256 {
    function verify(bytes32 messageHash, bytes32 r, bytes32 s, bytes32 qx, bytes32 qy) external view returns (bool valid);
}

// 10. DistrClaim Precompile (0x0000000000000000000000000000000000000A01)
interface IDistrClaim {
    function claimRewardsAndConvertCoin(address delegator, uint32 maxRetrieve, string calldata denom) external returns (uint256 amount);
}

/**
 * @title PrecompileHarness
 * @notice Security harness used for static analysis with Slither and fuzzing precompile entrypoints.
 */
contract PrecompileHarness {
    address public constant BECH32_ADDR = 0x0000000000000000000000000000000000000400;
    address public constant BANK_ADDR = 0x0000000000000000000000000000000000000804;
    address public constant STAKING_ADDR = 0x0000000000000000000000000000000000000800;
    address public constant DISTR_ADDR = 0x0000000000000000000000000000000000000801;
    address public constant ICS20_ADDR = 0x0000000000000000000000000000000000000802;
    address public constant GOV_ADDR = 0x0000000000000000000000000000000000000805;
    address public constant VESTING_ADDR = 0x0000000000000000000000000000000000000803;
    address public constant SLASHING_ADDR = 0x0000000000000000000000000000000000000806;
    address public constant P256_ADDR = 0x0000000000000000000000000000000000000100;
    address public constant DISTRCLAIM_ADDR = 0x0000000000000000000000000000000000000a01;

    event HarnessBech32Conversion(address indexed input, string output);
    event HarnessBankTransfer(string to, string denom, uint256 amount);
    event HarnessStakingDelegated(string validator, uint256 amount);
    event HarnessClaimRewards(address indexed delegator, string denom, uint256 claimed);

    function testBech32Conversion(address addr, string calldata prefix) external returns (string memory) {
        string memory result = IBech32(BECH32_ADDR).hexToBech32(addr, prefix);
        emit HarnessBech32Conversion(addr, result);
        return result;
    }

    function testBankTransfer(string calldata to, string calldata denom, uint256 amount) external returns (bool) {
        bool success = IBank(BANK_ADDR).send(to, denom, amount);
        emit HarnessBankTransfer(to, denom, amount);
        return success;
    }

    function testStakingDelegate(string calldata validator, uint256 amount) external returns (bool) {
        bool success = IStaking(STAKING_ADDR).delegate(validator, amount);
        emit HarnessStakingDelegated(validator, amount);
        return success;
    }

    function testClaimAndConvert(address delegator, uint32 maxRetrieve, string calldata denom) external returns (uint256) {
        uint256 amount = IDistrClaim(DISTRCLAIM_ADDR).claimRewardsAndConvertCoin(delegator, maxRetrieve, denom);
        emit HarnessClaimRewards(delegator, denom, amount);
        return amount;
    }

    function testP256Verification(bytes32 hash, bytes32 r, bytes32 s, bytes32 qx, bytes32 qy) external view returns (bool) {
        return IP256(P256_ADDR).verify(hash, r, s, qx, qy);
    }
}
