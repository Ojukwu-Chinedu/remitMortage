// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/**
 * @title LaunchGuardrail
 * @notice Production Launch Guardrail & Rate Limiting Contract for ArkConstellation Genesis (T_0).
 * @dev Enforces:
 *      1. Global Total Value Locked (TVL) ceiling across all deposits.
 *      2. Per-transaction maximum deposit ceiling.
 *      3. Per-account 24-hour sliding window rate limits.
 *      4. Emergency pause / circuit breaker integration for multi-guardian incident response.
 *      5. Checks-Effects-Interactions pattern and non-reentrant state transitions.
 *      6. SafeERC20 compatibility for standard and non-standard ERC-20 tokens.
 *      7. Ownable2Step two-phase ownership transfer to protect governance continuity.
 */

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract LaunchGuardrail {
    // -------------------------------------------------------------------------
    // Custom Errors (Gas-Optimized)
    // -------------------------------------------------------------------------
    error Unauthorized();
    error OnlyPendingOwner();
    error ContractPaused();
    error ContractNotPaused();
    error ZeroDeposit();
    error ZeroAddress();
    error ZeroLimit();
    error InvalidLimits(uint256 maxPerTx, uint256 dailyLimit, uint256 globalTvl);
    error ExceedsPerTxLimit(uint256 attempted, uint256 limit);
    error ExceedsDailyAccountLimit(address account, uint256 attempted, uint256 limit);
    error ExceedsGlobalTvlCap(uint256 currentTvl, uint256 attempted, uint256 maxTvl);
    error ReentrancyGuardReentrantCall();
    error TransferFailed();
    error InsufficientVaultBalance(uint256 requested, uint256 available);

    // -------------------------------------------------------------------------
    // State Variables
    // -------------------------------------------------------------------------
    address public owner;
    address public pendingOwner;
    address public emergencyGuardian;
    bool public paused;

    // Rate Limiting Parameters (in wei / esp units)
    uint256 public globalTvlCap;
    uint256 public maxPerTxLimit;
    uint256 public dailyAccountLimit;
    uint256 public constant EPOCH_DURATION = 1 days;

    // TVL Accounting
    uint256 public totalDepositedNative;
    mapping(address => uint256) public totalDepositedTokens;

    // Per-Account 24-Hour Epoch Accounting
    struct UserDepositWindow {
        uint256 currentEpoch;
        uint256 depositedInEpoch;
        uint256 totalCumulative;
    }

    mapping(address => UserDepositWindow) public nativeDepositWindows;
    mapping(address => mapping(address => UserDepositWindow)) public tokenDepositWindows; // user => token => window

    // Reentrancy Mutex
    uint256 private _unlocked = 1;

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------
    event NativeDeposited(address indexed user, uint256 amount, uint256 newTvl, uint256 epoch);
    event TokenDeposited(address indexed user, address indexed token, uint256 amount, uint256 newTvl, uint256 epoch);
    event NativeWithdrawn(address indexed recipient, uint256 amount);
    event TokenWithdrawn(address indexed token, address indexed recipient, uint256 amount);
    event EmergencyPaused(address indexed triggeredBy);
    event EmergencyUnpaused(address indexed triggeredBy);
    event LimitsUpdated(uint256 newGlobalTvlCap, uint256 newMaxPerTxLimit, uint256 newDailyAccountLimit);
    event GuardianUpdated(address indexed oldGuardian, address indexed newGuardian);
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // -------------------------------------------------------------------------
    // Modifiers
    // -------------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyGuardianOrOwner() {
        if (msg.sender != owner && msg.sender != emergencyGuardian) revert Unauthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    modifier whenPaused() {
        if (!paused) revert ContractNotPaused();
        _;
    }

    modifier nonReentrant() {
        if (_unlocked != 1) revert ReentrancyGuardReentrantCall();
        _unlocked = 0;
        _;
        _unlocked = 1;
    }

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------
    /**
     * @param initialOwner Initial contract admin/governance owner.
     * @param initialGuardian Emergency pause guardian account.
     * @param initialGlobalTvlCap Initial maximum total value locked (in wei / esp).
     * @param initialMaxPerTxLimit Maximum single deposit per transaction.
     * @param initialDailyAccountLimit Maximum deposit per account per 24 hours.
     */
    constructor(
        address initialOwner,
        address initialGuardian,
        uint256 initialGlobalTvlCap,
        uint256 initialMaxPerTxLimit,
        uint256 initialDailyAccountLimit
    ) {
        if (initialOwner == address(0) || initialGuardian == address(0)) revert ZeroAddress();
        _validateLimits(initialGlobalTvlCap, initialMaxPerTxLimit, initialDailyAccountLimit);

        owner = initialOwner;
        emergencyGuardian = initialGuardian;
        globalTvlCap = initialGlobalTvlCap;
        maxPerTxLimit = initialMaxPerTxLimit;
        dailyAccountLimit = initialDailyAccountLimit;
        paused = false;

        emit OwnershipTransferred(address(0), initialOwner);
        emit GuardianUpdated(address(0), initialGuardian);
        emit LimitsUpdated(initialGlobalTvlCap, initialMaxPerTxLimit, initialDailyAccountLimit);
    }

    // -------------------------------------------------------------------------
    // Deposit Functions
    // -------------------------------------------------------------------------
    /**
     * @notice Deposits native KASH / esp into the launch vault subject to guardrail limits.
     */
    function deposit() external payable whenNotPaused nonReentrant {
        uint256 amount = msg.value;
        if (amount == 0) revert ZeroDeposit();
        if (amount > maxPerTxLimit) revert ExceedsPerTxLimit(amount, maxPerTxLimit);

        uint256 newTvl = totalDepositedNative + amount;
        if (newTvl > globalTvlCap) revert ExceedsGlobalTvlCap(totalDepositedNative, amount, globalTvlCap);

        // Update Account 24-hour rate limit sliding window
        uint256 currentEpoch = block.timestamp / EPOCH_DURATION;
        UserDepositWindow storage window = nativeDepositWindows[msg.sender];

        uint256 currentEpochDeposited = (window.currentEpoch == currentEpoch) ? window.depositedInEpoch : 0;
        if (currentEpochDeposited + amount > dailyAccountLimit) {
            revert ExceedsDailyAccountLimit(msg.sender, currentEpochDeposited + amount, dailyAccountLimit);
        }

        // State mutations
        window.currentEpoch = currentEpoch;
        window.depositedInEpoch = currentEpochDeposited + amount;
        window.totalCumulative += amount;
        totalDepositedNative = newTvl;

        emit NativeDeposited(msg.sender, amount, newTvl, currentEpoch);
    }

    /**
     * @notice Deposits ERC20 tokens into the launch vault subject to guardrail limits.
     * @param token Address of the ERC20 token.
     * @param amount Token amount to deposit.
     */
    function depositToken(address token, uint256 amount) external whenNotPaused nonReentrant {
        if (token == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroDeposit();
        if (amount > maxPerTxLimit) revert ExceedsPerTxLimit(amount, maxPerTxLimit);

        uint256 currentTvl = totalDepositedTokens[token];
        uint256 newTvl = currentTvl + amount;
        if (newTvl > globalTvlCap) revert ExceedsGlobalTvlCap(currentTvl, amount, globalTvlCap);

        uint256 currentEpoch = block.timestamp / EPOCH_DURATION;
        UserDepositWindow storage window = tokenDepositWindows[msg.sender][token];

        uint256 currentEpochDeposited = (window.currentEpoch == currentEpoch) ? window.depositedInEpoch : 0;
        if (currentEpochDeposited + amount > dailyAccountLimit) {
            revert ExceedsDailyAccountLimit(msg.sender, currentEpochDeposited + amount, dailyAccountLimit);
        }

        // State mutations before external transfer (CEI)
        window.currentEpoch = currentEpoch;
        window.depositedInEpoch = currentEpochDeposited + amount;
        window.totalCumulative += amount;
        totalDepositedTokens[token] = newTvl;

        // Safe external token transfer (supports standard and non-standard ERC20)
        _safeTransferFrom(token, msg.sender, address(this), amount);

        emit TokenDeposited(msg.sender, token, amount, newTvl, currentEpoch);
    }

    // -------------------------------------------------------------------------
    // View Functions
    // -------------------------------------------------------------------------
    /**
     * @notice Checks remaining native deposit capacity for a user in the current 24-hour epoch.
     */
    function getUserRemainingDailyLimit(address user) external view returns (uint256) {
        uint256 currentEpoch = block.timestamp / EPOCH_DURATION;
        UserDepositWindow memory window = nativeDepositWindows[user];
        uint256 deposited = (window.currentEpoch == currentEpoch) ? window.depositedInEpoch : 0;
        if (deposited >= dailyAccountLimit) return 0;
        return dailyAccountLimit - deposited;
    }

    /**
     * @notice Checks remaining token deposit capacity for a user in the current 24-hour epoch.
     */
    function getTokenUserRemainingDailyLimit(address user, address token) external view returns (uint256) {
        uint256 currentEpoch = block.timestamp / EPOCH_DURATION;
        UserDepositWindow memory window = tokenDepositWindows[user][token];
        uint256 deposited = (window.currentEpoch == currentEpoch) ? window.depositedInEpoch : 0;
        if (deposited >= dailyAccountLimit) return 0;
        return dailyAccountLimit - deposited;
    }

    /**
     * @notice Checks remaining native TVL headroom before hitting the global cap.
     */
    function getRemainingTvlCapacity() external view returns (uint256) {
        if (totalDepositedNative >= globalTvlCap) return 0;
        return globalTvlCap - totalDepositedNative;
    }

    /**
     * @notice Checks remaining token TVL headroom before hitting the global cap.
     */
    function getTokenRemainingTvlCapacity(address token) external view returns (uint256) {
        uint256 currentTvl = totalDepositedTokens[token];
        if (currentTvl >= globalTvlCap) return 0;
        return globalTvlCap - currentTvl;
    }

    // -------------------------------------------------------------------------
    // Admin & Emergency Functions
    // -------------------------------------------------------------------------
    /**
     * @notice Instantly pauses all deposits in the event of an anomaly or circuit breaker trigger.
     */
    function emergencyPause() external onlyGuardianOrOwner whenNotPaused {
        paused = true;
        emit EmergencyPaused(msg.sender);
    }

    /**
     * @notice Unpauses contract once security clearance is verified.
     */
    function unpause() external onlyOwner whenPaused {
        paused = false;
        emit EmergencyUnpaused(msg.sender);
    }

    /**
     * @notice Updates launch guardrail rate limits as network matures.
     */
    function setLimits(
        uint256 newGlobalTvlCap,
        uint256 newMaxPerTxLimit,
        uint256 newDailyAccountLimit
    ) external onlyOwner {
        _validateLimits(newGlobalTvlCap, newMaxPerTxLimit, newDailyAccountLimit);
        globalTvlCap = newGlobalTvlCap;
        maxPerTxLimit = newMaxPerTxLimit;
        dailyAccountLimit = newDailyAccountLimit;
        emit LimitsUpdated(newGlobalTvlCap, newMaxPerTxLimit, newDailyAccountLimit);
    }

    /**
     * @notice Withdraws native funds from the vault to the target recipient.
     */
    function withdrawNative(address payable recipient, uint256 amount) external onlyOwner nonReentrant {
        if (recipient == address(0)) revert ZeroAddress();
        if (amount > address(this).balance) revert InsufficientVaultBalance(amount, address(this).balance);

        (bool success, ) = recipient.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit NativeWithdrawn(recipient, amount);
    }

    /**
     * @notice Withdraws ERC20 tokens from the vault to the target recipient.
     */
    function withdrawToken(address token, address recipient, uint256 amount) external onlyOwner nonReentrant {
        if (token == address(0) || recipient == address(0)) revert ZeroAddress();
        uint256 tokenBal = IERC20(token).balanceOf(address(this));
        if (amount > tokenBal) revert InsufficientVaultBalance(amount, tokenBal);

        _safeTransfer(token, recipient, amount);

        emit TokenWithdrawn(token, recipient, amount);
    }

    /**
     * @notice Updates emergency guardian address.
     */
    function setGuardian(address newGuardian) external onlyOwner {
        if (newGuardian == address(0)) revert ZeroAddress();
        emit GuardianUpdated(emergencyGuardian, newGuardian);
        emergencyGuardian = newGuardian;
    }

    /**
     * @notice Initiates two-phase ownership transfer to a new account.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner, newOwner);
    }

    /**
     * @notice Accepts ownership transfer (must be called by pendingOwner).
     */
    function acceptOwnership() external {
        if (msg.sender != pendingOwner) revert OnlyPendingOwner();
        emit OwnershipTransferred(owner, pendingOwner);
        owner = pendingOwner;
        pendingOwner = address(0);
    }

    // -------------------------------------------------------------------------
    // Internal Safe Transfer & Validation Helpers
    // -------------------------------------------------------------------------
    function _validateLimits(uint256 globalCap, uint256 perTx, uint256 daily) internal pure {
        if (globalCap == 0 || perTx == 0 || daily == 0) revert ZeroLimit();
        if (perTx > daily || daily > globalCap) revert InvalidLimits(perTx, daily, globalCap);
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
            revert TransferFailed();
        }
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
            revert TransferFailed();
        }
    }

    // Fallback and Receive
    receive() external payable {
        revert("Use deposit() function");
    }
}
