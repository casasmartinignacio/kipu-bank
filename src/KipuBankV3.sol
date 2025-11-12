// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/interfaces/IUniswapV2Router02.sol";

/**
 * @title KipuBankV3
 * @author Martin Ignacio Casas
 * @notice Banco descentralizado que acepta cualquier token soportado por Uniswap V2,
 *         lo convierte a USDC automáticamente y mantiene balances en USDC
 * @dev Integra Uniswap V2 para swaps automáticos, preserva funcionalidad de KipuBankV2
 */
contract KipuBankV3 is Ownable {
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

    /// @notice Address representing native ETH
    address private constant NATIVE_TOKEN = address(0);

    /// @notice Slippage tolerance: 1% (100 basis points)
    uint256 private constant SLIPPAGE_TOLERANCE = 100; // 1%
    uint256 private constant BASIS_POINTS = 10000;

    /*////////////////////////
            Immutable Variables
    ////////////////////////*/

    /// @notice Maximum amount that can be withdrawn per transaction (in USDC, 6 decimals)
    uint256 public immutable i_withdrawalLimit;

    /// @notice Uniswap V2 Router address
    IUniswapV2Router02 public immutable i_uniswapRouter;

    /// @notice USDC token address
    address public immutable i_usdcAddress;

    /*////////////////////////
            State Variables
    ////////////////////////*/

    /// @notice Maximum total USDC the bank can hold (6 decimals)
    uint256 public s_bankCap;

    /// @notice Mapping of user address to their USDC balance
    mapping(address user => uint256 balance) public s_balances;

    /// @notice Mapping to store information about supported tokens
    mapping(address token => TokenInfo) public s_supportedTokens;

    /// @notice Counter for total number of deposits
    uint256 public s_totalDeposits;

    /// @notice Counter for total number of withdrawals
    uint256 public s_totalWithdrawals;

    /// @notice Current total balance in USDC
    uint256 public s_currentTotalBalance;

    /*////////////////////////
            Events
    ////////////////////////*/

    /// @notice Event emitted when a deposit is made (after swap to USDC)
    event KipuBank_DepositMade(
        address indexed user, address indexed tokenIn, uint256 amountIn, uint256 usdcReceived
    );

    /// @notice Event emitted when a withdrawal is made
    event KipuBank_WithdrawalMade(address indexed user, uint256 amount);

    /// @notice Event emitted when bank capacity is updated
    event KipuBank_BankCapUpdated(uint256 newCap, uint256 timestamp);

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

    /// @notice Error emitted when token is not supported
    error KipuBank_TokenNotSupported(address token);

    /// @notice Error emitted when swap fails or returns insufficient output
    error KipuBank_SwapFailed();

    /// @notice Error emitted when deadline has passed
    error KipuBank_DeadlineExpired();

    /// @notice Error emitted when address is zero
    error KipuBank_ZeroAddress();

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
     * @param _withdrawalLimit Maximum amount that can be withdrawn per transaction (in USDC)
     * @param _bankCap Maximum total capacity the bank can hold (in USDC)
     * @param _uniswapRouter Address of Uniswap V2 Router
     * @param _usdcAddress Address of USDC token
     * @param _owner Address of the contract owner
     */
    constructor(
        uint256 _withdrawalLimit,
        uint256 _bankCap,
        address _uniswapRouter,
        address _usdcAddress,
        address _owner
    ) Ownable(_owner) {
        if (_uniswapRouter == address(0) || _usdcAddress == address(0)) {
            revert KipuBank_ZeroAddress();
        }

        i_withdrawalLimit = _withdrawalLimit;
        s_bankCap = _bankCap;
        i_uniswapRouter = IUniswapV2Router02(_uniswapRouter);
        i_usdcAddress = _usdcAddress;

        // Add native ETH and USDC as supported tokens
        s_supportedTokens[NATIVE_TOKEN] = TokenInfo({isSupported: true, decimals: 18, symbol: "ETH"});
        s_supportedTokens[_usdcAddress] = TokenInfo({isSupported: true, decimals: 6, symbol: "USDC"});
    }

    /*////////////////////////
        External Functions
    ////////////////////////*/

    /**
     * @notice Function to deposit native ETH, swap to USDC, and credit user
     * @dev Swaps ETH to USDC via Uniswap V2 and credits the resulting USDC to user's balance
     */
    function deposit() external payable validAmount(msg.value) {
        // Swap ETH to USDC
        uint256 usdcReceived = _swapETHToUSDC(msg.value);

        // Validate bank cap
        if (s_currentTotalBalance + usdcReceived > s_bankCap) {
            revert KipuBank_BankCapacityExceeded(s_bankCap - s_currentTotalBalance);
        }

        // Update state
        s_balances[msg.sender] += usdcReceived;
        s_currentTotalBalance += usdcReceived;
        s_totalDeposits += 1;

        emit KipuBank_DepositMade(msg.sender, NATIVE_TOKEN, msg.value, usdcReceived);
    }

    /**
     * @notice Function to deposit ERC-20 tokens, swap to USDC if needed, and credit user
     * @param _token Address of the ERC-20 token to deposit
     * @param _amount Amount of tokens to deposit
     * @dev If token is USDC, credits directly. Otherwise, swaps to USDC via Uniswap V2
     */
    function depositToken(address _token, uint256 _amount) external validAmount(_amount) {
        if (!s_supportedTokens[_token].isSupported) {
            revert KipuBank_TokenNotSupported(_token);
        }

        // Transfer tokens from user to contract
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

        uint256 usdcReceived;

        // If token is already USDC, no swap needed
        if (_token == i_usdcAddress) {
            usdcReceived = _amount;
        } else {
            // Swap token to USDC
            usdcReceived = _swapTokenToUSDC(_token, _amount);
        }

        // Validate bank cap
        if (s_currentTotalBalance + usdcReceived > s_bankCap) {
            revert KipuBank_BankCapacityExceeded(s_bankCap - s_currentTotalBalance);
        }

        // Update state
        s_balances[msg.sender] += usdcReceived;
        s_currentTotalBalance += usdcReceived;
        s_totalDeposits += 1;

        emit KipuBank_DepositMade(msg.sender, _token, _amount, usdcReceived);
    }

    /**
     * @notice Function to withdraw USDC from user's vault
     * @param _amount Amount of USDC to withdraw
     * @dev Follows checks-effects-interactions pattern
     */
    function withdraw(uint256 _amount) external validAmount(_amount) {
        if (_amount > i_withdrawalLimit) {
            revert KipuBank_WithdrawalLimitExceeded(_amount, i_withdrawalLimit);
        }

        if (s_balances[msg.sender] < _amount) {
            revert KipuBank_InsufficientBalance(s_balances[msg.sender], _amount);
        }

        // Effects
        s_balances[msg.sender] -= _amount;
        s_currentTotalBalance -= _amount;
        s_totalWithdrawals += 1;

        // Interactions
        IERC20(i_usdcAddress).safeTransfer(msg.sender, _amount);

        emit KipuBank_WithdrawalMade(msg.sender, _amount);
    }

    /*////////////////////////
        Owner Functions
    ////////////////////////*/

    /**
     * @notice Function to update the bank capacity in USDC
     * @param _newBankCap New bank capacity in USDC (6 decimals)
     * @dev Only callable by owner
     */
    function setBankCap(uint256 _newBankCap) external onlyOwner {
        s_bankCap = _newBankCap;
        emit KipuBank_BankCapUpdated(_newBankCap, block.timestamp);
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
     * @notice Function to get the caller's USDC balance
     * @return balance_ User's current USDC balance
     */
    function getBalance() external view returns (uint256 balance_) {
        balance_ = s_balances[msg.sender];
    }

    /**
     * @notice Function to get a specific user's USDC balance
     * @param _user Address of the user
     * @return balance_ User's current USDC balance
     */
    function getBalanceOf(address _user) external view returns (uint256 balance_) {
        balance_ = s_balances[_user];
    }

    /**
     * @notice Function to get the withdrawal limit
     * @return limit_ Maximum withdrawal amount per transaction (in USDC)
     */
    function getWithdrawalLimit() external view returns (uint256 limit_) {
        limit_ = i_withdrawalLimit;
    }

    /**
     * @notice Function to get the bank capacity
     * @return cap_ Maximum capacity of the bank (in USDC)
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
     * @notice Function to get the contract's current total USDC balance
     * @return balance_ Contract's current total USDC balance
     */
    function getCurrentTotalBalance() external view returns (uint256 balance_) {
        balance_ = s_currentTotalBalance;
    }

    /*////////////////////////
        Internal Functions
    ////////////////////////*/

    /**
     * @notice Internal function to swap ETH to USDC via Uniswap V2
     * @param _amountIn Amount of ETH to swap (in wei)
     * @return usdcReceived Amount of USDC received after swap
     * @dev Uses swapExactETHForTokens from Uniswap V2 Router
     */
    function _swapETHToUSDC(uint256 _amountIn) private returns (uint256 usdcReceived) {
        // Calculate minimum amount out with slippage tolerance
        // This is a simplified approach; in production, use price oracles
        address[] memory path = new address[](2);
        path[0] = i_uniswapRouter.WETH();
        path[1] = i_usdcAddress;

        // Get expected amounts from Uniswap
        uint256[] memory amountsOut = i_uniswapRouter.getAmountsOut(_amountIn, path);
        uint256 expectedUsdcOut = amountsOut[1];

        // Apply slippage tolerance
        uint256 minAmountOut = (expectedUsdcOut * (BASIS_POINTS - SLIPPAGE_TOLERANCE)) / BASIS_POINTS;

        // Set deadline to 15 minutes from now
        uint256 deadline = block.timestamp + 15 minutes;

        // Execute swap
        uint256[] memory amounts = i_uniswapRouter.swapExactETHForTokens{value: _amountIn}(
            minAmountOut, path, address(this), deadline
        );

        usdcReceived = amounts[1];

        if (usdcReceived == 0) revert KipuBank_SwapFailed();
    }

    /**
     * @notice Internal function to swap any ERC-20 token to USDC via Uniswap V2
     * @param _tokenIn Address of the input token
     * @param _amountIn Amount of input token to swap
     * @return usdcReceived Amount of USDC received after swap
     * @dev Uses swapExactTokensForTokens from Uniswap V2 Router
     */
    function _swapTokenToUSDC(address _tokenIn, uint256 _amountIn) private returns (uint256 usdcReceived) {
        // Approve Uniswap Router to spend tokens
        IERC20(_tokenIn).safeIncreaseAllowance(address(i_uniswapRouter), _amountIn);

        // Create path: Token -> WETH -> USDC (for better liquidity)
        address[] memory path = new address[](3);
        path[0] = _tokenIn;
        path[1] = i_uniswapRouter.WETH();
        path[2] = i_usdcAddress;

        // Get expected amounts from Uniswap
        uint256[] memory amountsOut = i_uniswapRouter.getAmountsOut(_amountIn, path);
        uint256 expectedUsdcOut = amountsOut[2];

        // Apply slippage tolerance
        uint256 minAmountOut = (expectedUsdcOut * (BASIS_POINTS - SLIPPAGE_TOLERANCE)) / BASIS_POINTS;

        // Set deadline to 15 minutes from now
        uint256 deadline = block.timestamp + 15 minutes;

        // Execute swap
        uint256[] memory amounts =
            i_uniswapRouter.swapExactTokensForTokens(_amountIn, minAmountOut, path, address(this), deadline);

        usdcReceived = amounts[2];

        if (usdcReceived == 0) revert KipuBank_SwapFailed();
    }
}
