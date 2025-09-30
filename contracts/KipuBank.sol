// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/**
 * @title KipuBank
 * @author Martin Ignacio Casas
 * @notice This contract allows users to deposit and withdraw ETH securely
 */
contract KipuBank {
    /*////////////////////////
            Variables
    ////////////////////////*/

    /// @notice Immutable variable to store the withdrawal limit per transaction
    uint256 public immutable i_withdrawalLimit;

    /// @notice Variable to store the maximum capacity of the bank
    uint256 public s_bankCap;

    /// @notice Mapping to store each user's balance
    mapping(address user => uint256 balance) public s_balances;

    /// @notice Counter for total number of deposits
    uint256 public s_totalDeposits;

    /// @notice Counter for total number of withdrawals
    uint256 public s_totalWithdrawals;

    /// @notice Variable to store the current total balance in the contract
    uint256 public s_currentTotalBalance;

    /*////////////////////////
            Events
    ////////////////////////*/

    /// @notice Event emitted when a deposit is made
    event KipuBank_DepositMade(address indexed user, uint256 amount);

    /// @notice Event emitted when a withdrawal is made
    event KipuBank_WithdrawalMade(address indexed user, uint256 amount);

    /*////////////////////////
        Custom Errors
    ////////////////////////*/

    /// @notice Error emitted when amount is zero or invalid
    error KipuBank_InvalidAmount();

    /// @notice Error emitted when withdrawal amount exceeds the limit
    error KipuBank_WithdrawalLimitExceeded(uint256 requestedAmount, uint256 allowedLimit);

    /// @notice Error emitted when user has insufficient balance
    error KipuBank_InsufficientBalance(uint256 availableBalance, uint256 requestedAmount);

    /// @notice Error emitted when deposit exceeds bank capacity
    error KipuBank_BankCapacityExceeded(uint256 remainingCapacity);

    /// @notice Error emitted when ETH transfer fails
    error KipuBank_TransferFailed(bytes error);

    /*////////////////////////
        Constructor
    ////////////////////////*/

    /**
     * @notice Constructor to initialize the contract
     * @param _withdrawalLimit Maximum amount that can be withdrawn per transaction
     * @param _bankCap Maximum total capacity the bank can hold
     */
    constructor(uint256 _withdrawalLimit, uint256 _bankCap) {
        i_withdrawalLimit = _withdrawalLimit;
        s_bankCap = _bankCap;
    }

    /*////////////////////////
        Modifiers
    ////////////////////////*/

    /**
     * @notice Modifier to validate that amount is greater than zero
     * @param _amount Amount to validate
     */
    modifier validAmount(uint256 _amount) {
        if (_amount == 0) revert KipuBank_InvalidAmount();
        _;
    }

    /*////////////////////////
        Functions
    ////////////////////////*/

    /**
     * @notice Function to deposit ETH into the user's personal vault
     * @dev This function is payable and checks bank capacity
     */
    function deposit() external payable validAmount(msg.value) {
        if (s_currentTotalBalance + msg.value > s_bankCap) {
            revert KipuBank_BankCapacityExceeded(s_bankCap - s_currentTotalBalance);
        }

        s_balances[msg.sender] = s_balances[msg.sender] + msg.value;
        s_currentTotalBalance = s_currentTotalBalance + msg.value;
        s_totalDeposits = s_totalDeposits + 1;

        emit KipuBank_DepositMade(msg.sender, msg.value);
    }

    /**
     * @notice Function to withdraw ETH from the user's vault
     * @param _amount Amount to withdraw
     * @dev Follows checks-effects-interactions pattern
     */
    function withdraw(uint256 _amount) external validAmount(_amount) {
        if (_amount > i_withdrawalLimit) {
            revert KipuBank_WithdrawalLimitExceeded(_amount, i_withdrawalLimit);
        }

        if (s_balances[msg.sender] < _amount) {
            revert KipuBank_InsufficientBalance(s_balances[msg.sender], _amount);
        }

        s_balances[msg.sender] = s_balances[msg.sender] - _amount;
        s_currentTotalBalance = s_currentTotalBalance - _amount;
        s_totalWithdrawals = s_totalWithdrawals + 1;

        _transferEth(_amount);

        emit KipuBank_WithdrawalMade(msg.sender, _amount);
    }

    /**
     * @notice Function to get the caller's balance
     * @return balance_ User's current balance
     */
    function getBalance() external view returns (uint256 balance_) {
        balance_ = s_balances[msg.sender];
    }

    /**
     * @notice Function to get the withdrawal limit
     * @return limit_ Maximum withdrawal amount per transaction
     */
    function getWithdrawalLimit() external view returns (uint256 limit_) {
        limit_ = i_withdrawalLimit;
    }

    /**
     * @notice Function to get the bank capacity
     * @return cap_ Maximum capacity of the bank
     */
    function getBankCap() external view returns (uint256 cap_) {
        cap_ = s_bankCap;
    }

    /**
     * @notice Function to get total number of deposits
     * @return total_ Total deposit count
     */
    function getTotalDeposits() external view returns (uint256 total_) {
        total_ = s_totalDeposits;
    }

    /**
     * @notice Function to get total number of withdrawals
     * @return total_ Total withdrawal count
     */
    function getTotalWithdrawals() external view returns (uint256 total_) {
        total_ = s_totalWithdrawals;
    }

    /**
     * @notice Function to get the contract's total balance
     * @return balance_ Contract's current total balance
     */
    function getContractBalance() external view returns (uint256 balance_) {
        balance_ = address(this).balance;
    }

    /**
     * @notice Private function to handle ETH transfers
     * @param _amount Amount to transfer
     */
    function _transferEth(uint256 _amount) private {
        (bool success, bytes memory error) = msg.sender.call{value: _amount}("");

        if (!success) revert KipuBank_TransferFailed(error);
    }
}