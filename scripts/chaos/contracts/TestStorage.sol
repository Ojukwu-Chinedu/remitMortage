// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title TestStorage
 * @dev Simple contract used to test EVM JSON-RPC contract deployment, execution,
 * state persistence, and event logging.
 */
contract TestStorage {
    uint256 private _value;
    address public immutable deployer;

    event ValueSet(address indexed setter, uint256 oldValue, uint256 newValue);
    event ContractInitialized(address indexed deployer, uint256 initialValue);

    error Unauthorized();
    error InvalidZeroValue();

    constructor(uint256 initialValue) {
        deployer = msg.sender;
        _value = initialValue;
        emit ContractInitialized(msg.sender, initialValue);
    }

    /**
     * @dev Sets a new value in storage and emits ValueSet event
     */
    function setValue(uint256 newValue) external {
        uint256 old = _value;
        _value = newValue;
        emit ValueSet(msg.sender, old, newValue);
    }

    /**
     * @dev Retrieves stored value
     */
    function getValue() external view returns (uint256) {
        return _value;
    }

    /**
     * @dev Pure helper to test transaction reversion
     */
    function testRevert(uint256 input) external pure returns (uint256) {
        if (input == 0) {
            revert InvalidZeroValue();
        }
        return input * 2;
    }
}
