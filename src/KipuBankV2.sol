// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title KipuBankV2
 * @author Martin Ignacio Casas
 * @notice This contract allows users to deposit and withdraw ETH and ERC-20 tokens securely
 * @dev Implements multi-token support, Chainlink price feeds, and security best practices
 */
contract KipuBankV2 is Ownable {
    using SafeERC20 for IERC20;

    /*////////////////////////
            Type Declarations
    ////////////////////////*/

    /// @notice Struct to store information about supported tokens
    struct TokenInfo {
        bool isSupported;
        uint8 decimals;
        string symbol;
    }

    /*////////////////////////
            Constants
    ////////////////////////*/

    /// @notice Heartbeat time for Chainlink oracle (1 hour)
    uint16 private constant ORACLE_HEARTBEAT = 3600;

    /// @notice Decimal factor to normalize values to 6 decimals (USDC standard)
    /// @dev Used to convert ETH (18 decimals) and oracle price (8 decimals) to 6 decimals
    uint256 private constant DECIMAL_FACTOR = 1e20;

    /// @notice Address representing native ETH
    address private constant NATIVE_TOKEN = address(0);

    /*////////////////////////
            Immutable Variables
    ////////////////////////*/

    /// @notice Immutable variable to store the withdrawal limit per transaction
    uint256 public immutable i_withdrawalLimit;

    /*////////////////////////
            State Variables
    ////////////////////////*/

    /// @notice Variable to store the maximum capacity of the bank in ETH
    uint256 public s_bankCap;

    /// @notice Chainlink ETH/USD price feed
    AggregatorV3Interface public s_ethUsdFeed;

    /// @notice Nested mapping to store each user's balance per token
    /// @dev First key is user address, second key is token address (address(0) for ETH)
    mapping(address user => mapping(address token => uint256 balance)) public s_balances;

    /// @notice Mapping to store information about supported tokens
    mapping(address token => TokenInfo) public s_supportedTokens;

    /// @notice Counter for total number of deposits
    uint256 public s_totalDeposits;

    /// @notice Counter for total number of withdrawals
    uint256 public s_totalWithdrawals;

    /// @notice Variable to store the current total balance in ETH equivalent
    uint256 public s_currentTotalBalance;

    /*////////////////////////
            Events
    ////////////////////////*/

    /// @notice Event emitted when a native ETH deposit is made
    event KipuBank_DepositMade(address indexed user, uint256 amount, uint256 usdValue);

    /// @notice Event emitted when a native ETH withdrawal is made
    event KipuBank_WithdrawalMade(address indexed user, uint256 amount, uint256 usdValue);

    /// @notice Event emitted when an ERC-20 token deposit is made
    event KipuBank_TokenDeposit(address indexed user, address indexed token, uint256 amount);

    /// @notice Event emitted when an ERC-20 token withdrawal is made
    event KipuBank_TokenWithdrawal(address indexed user, address indexed token, uint256 amount);

    /// @notice Event emitted when bank capacity is updated
    event KipuBank_BankCapUpdated(uint256 newCap, uint256 timestamp);

    /// @notice Event emitted when the Chainlink feed address is updated
    event KipuBank_EthUsdFeedUpdated(address newFeed);

    /// @notice Event emitted when a new token is added to supported list
    event KipuBank_TokenAdded(address indexed token, string symbol, uint8 decimals);

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

    /// @notice Error emitted when oracle returns invalid price
    error KipuBank_OracleCompromised();

    /// @notice Error emitted when oracle price is stale
    error KipuBank_StalePrice();

    /// @notice Error emitted when token is not supported
    error KipuBank_TokenNotSupported(address token);

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
        Constructor
    ////////////////////////*/

    /**
     * @notice Constructor to initialize the contract
     * @param _withdrawalLimit Maximum amount that can be withdrawn per transaction
     * @param _bankCap Maximum total capacity the bank can hold in ETH
     * @param _ethUsdFeed Address of the Chainlink ETH/USD price feed
     * @param _owner Address of the contract owner
     */
    constructor(uint256 _withdrawalLimit, uint256 _bankCap, address _ethUsdFeed, address _owner)
        Ownable(_owner)
    {
        i_withdrawalLimit = _withdrawalLimit;
        s_bankCap = _bankCap;
        s_ethUsdFeed = AggregatorV3Interface(_ethUsdFeed);

        // Add native ETH as supported token
        s_supportedTokens[NATIVE_TOKEN] = TokenInfo({isSupported: true, decimals: 18, symbol: "ETH"});
    }

    /*////////////////////////
        External Functions
    ////////////////////////*/

    /**
     * @notice Function to deposit ETH into the user's personal vault
     * @dev This function is payable and checks bank capacity
     */
    function deposit() external payable validAmount(msg.value) {
        if (s_currentTotalBalance + msg.value > s_bankCap) {
            revert KipuBank_BankCapacityExceeded(s_bankCap - s_currentTotalBalance);
        }

        s_balances[msg.sender][NATIVE_TOKEN] += msg.value;
        s_currentTotalBalance += msg.value;
        s_totalDeposits += 1;

        uint256 usdValue = convertEthToUsd(msg.value);
        emit KipuBank_DepositMade(msg.sender, msg.value, usdValue);
    }

    /**
     * @notice Function to deposit ERC-20 tokens into the user's vault
     * @param _token Address of the ERC-20 token
     * @param _amount Amount of tokens to deposit
     * @dev Uses SafeERC20 for secure transfers
     */
    function depositToken(address _token, uint256 _amount) external validAmount(_amount) {
        if (!s_supportedTokens[_token].isSupported) {
            revert KipuBank_TokenNotSupported(_token);
        }

        s_balances[msg.sender][_token] += _amount;
        s_totalDeposits += 1;

        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

        emit KipuBank_TokenDeposit(msg.sender, _token, _amount);
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

        if (s_balances[msg.sender][NATIVE_TOKEN] < _amount) {
            revert KipuBank_InsufficientBalance(s_balances[msg.sender][NATIVE_TOKEN], _amount);
        }

        s_balances[msg.sender][NATIVE_TOKEN] -= _amount;
        s_currentTotalBalance -= _amount;
        s_totalWithdrawals += 1;

        uint256 usdValue = convertEthToUsd(_amount);

        _transferEth(_amount);

        emit KipuBank_WithdrawalMade(msg.sender, _amount, usdValue);
    }

    /**
     * @notice Function to withdraw ERC-20 tokens from the user's vault
     * @param _token Address of the ERC-20 token
     * @param _amount Amount of tokens to withdraw
     * @dev Uses SafeERC20 for secure transfers
     */
    function withdrawToken(address _token, uint256 _amount) external validAmount(_amount) {
        if (!s_supportedTokens[_token].isSupported) {
            revert KipuBank_TokenNotSupported(_token);
        }

        if (s_balances[msg.sender][_token] < _amount) {
            revert KipuBank_InsufficientBalance(s_balances[msg.sender][_token], _amount);
        }

        s_balances[msg.sender][_token] -= _amount;
        s_totalWithdrawals += 1;

        IERC20(_token).safeTransfer(msg.sender, _amount);

        emit KipuBank_TokenWithdrawal(msg.sender, _token, _amount);
    }

    /*////////////////////////
        Owner Functions
    ////////////////////////*/

    /**
     * @notice Function to update the bank capacity
     * @param _newBankCap New bank capacity in ETH
     * @dev Only callable by owner
     */
    function setBankCap(uint256 _newBankCap) external onlyOwner {
        s_bankCap = _newBankCap;
        emit KipuBank_BankCapUpdated(_newBankCap, block.timestamp);
    }

    /**
     * @notice Function to update the bank capacity based on USD value
     * @param _capInUsd Desired bank capacity in USD (with 8 decimals like Chainlink)
     * @dev Converts USD to ETH using current oracle price
     */
    function setBankCapInUSD(uint256 _capInUsd) external onlyOwner {
        uint256 ethUsdPrice = getEthUsdPrice();
        // Convert USD to ETH: (capInUsd * 1e18) / ethUsdPrice
        // Since ethUsdPrice has 8 decimals, we need to adjust
        uint256 newBankCapInEth = (_capInUsd * 1e18) / ethUsdPrice;
        s_bankCap = newBankCapInEth;
        emit KipuBank_BankCapUpdated(newBankCapInEth, block.timestamp);
    }

    /**
     * @notice Function to update the Chainlink ETH/USD feed address
     * @param _newFeed Address of the new Chainlink feed
     * @dev Only callable by owner
     */
    function setEthUsdFeed(address _newFeed) external onlyOwner {
        s_ethUsdFeed = AggregatorV3Interface(_newFeed);
        emit KipuBank_EthUsdFeedUpdated(_newFeed);
    }

    /**
     * @notice Function to add a new supported token
     * @param _token Address of the token to add
     * @param _symbol Symbol of the token
     * @param _decimals Decimals of the token
     * @dev Only callable by owner
     */
    function addSupportedToken(address _token, string memory _symbol, uint8 _decimals) external onlyOwner {
        s_supportedTokens[_token] = TokenInfo({isSupported: true, decimals: _decimals, symbol: _symbol});
        emit KipuBank_TokenAdded(_token, _symbol, _decimals);
    }

    /*////////////////////////
        View Functions
    ////////////////////////*/

    /**
     * @notice Function to get the caller's balance for a specific token
     * @param _token Address of the token (use address(0) for ETH)
     * @return balance_ User's current balance
     */
    function getBalance(address _token) external view returns (uint256 balance_) {
        balance_ = s_balances[msg.sender][_token];
    }

    /**
     * @notice Function to get the caller's ETH balance
     * @return balance_ User's current ETH balance
     */
    function getBalance() external view returns (uint256 balance_) {
        balance_ = s_balances[msg.sender][NATIVE_TOKEN];
    }

    /**
     * @notice Function to get a user's balance in USD
     * @param _user Address of the user
     * @return usdBalance_ User's ETH balance converted to USD
     */
    function getUserBalanceInUsd(address _user) external view returns (uint256 usdBalance_) {
        uint256 ethBalance = s_balances[_user][NATIVE_TOKEN];
        usdBalance_ = convertEthToUsd(ethBalance);
    }

    /**
     * @notice Function to get the bank capacity in USD
     * @return capInUsd_ Bank capacity converted to USD
     */
    function getBankCapInUsd() external view returns (uint256 capInUsd_) {
        capInUsd_ = convertEthToUsd(s_bankCap);
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
     * @notice Function to get current ETH/USD price from Chainlink
     * @return price_ Current ETH price in USD (8 decimals)
     */
    function getEthUsdPrice() public view returns (uint256 price_) {
        (, int256 ethUsdPrice,, uint256 updatedAt,) = s_ethUsdFeed.latestRoundData();

        if (ethUsdPrice <= 0) revert KipuBank_OracleCompromised();
        if (block.timestamp - updatedAt > ORACLE_HEARTBEAT) revert KipuBank_StalePrice();

        price_ = uint256(ethUsdPrice);
    }

    /**
     * @notice Function to convert ETH amount to USD
     * @param _ethAmount Amount of ETH to convert (18 decimals)
     * @return usdAmount_ Equivalent USD amount (6 decimals, USDC standard)
     * @dev Formula: (ethAmount * ethUsdPrice) / DECIMAL_FACTOR
     */
    function convertEthToUsd(uint256 _ethAmount) public view returns (uint256 usdAmount_) {
        uint256 ethUsdPrice = getEthUsdPrice();
        // ethAmount has 18 decimals, ethUsdPrice has 8 decimals
        // Result should have 6 decimals (USDC standard)
        // (18 + 8 - 20 = 6 decimals)
        usdAmount_ = (_ethAmount * ethUsdPrice) / DECIMAL_FACTOR;
    }

    /*////////////////////////
        Internal Functions
    ////////////////////////*/

    /**
     * @notice Private function to handle ETH transfers
     * @param _amount Amount to transfer
     */
    function _transferEth(uint256 _amount) private {
        (bool success, bytes memory error) = msg.sender.call{value: _amount}("");

        if (!success) revert KipuBank_TransferFailed(error);
    }
}
