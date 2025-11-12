// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {KipuBankV3} from "../src/KipuBankV3.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title KipuBankV3Test
 * @notice Test suite for KipuBankV3 contract
 * @dev Tests are designed to run on Sepolia fork to interact with real Uniswap V2
 */
contract KipuBankV3Test is Test {
    KipuBankV3 public kipuBank;

    // Sepolia addresses
    address constant UNISWAP_V2_ROUTER = 0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008;
    address constant USDC_SEPOLIA = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    address constant WETH_SEPOLIA = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;

    // Test accounts
    address public owner;
    address public user1;
    address public user2;

    // Contract parameters
    uint256 constant WITHDRAWAL_LIMIT = 1000 * 10 ** 6; // 1000 USDC
    uint256 constant BANK_CAP = 100000 * 10 ** 6; // 100,000 USDC
    uint256 constant INITIAL_ETH_BALANCE = 100 ether;

    // Events to test
    event KipuBank_DepositMade(
        address indexed user, address indexed tokenIn, uint256 amountIn, uint256 usdcReceived
    );
    event KipuBank_WithdrawalMade(address indexed user, uint256 amount);
    event KipuBank_BankCapUpdated(uint256 newCap, uint256 timestamp);
    event KipuBank_TokenAdded(address indexed token, string symbol, uint8 decimals);

    function setUp() public {
        // Fork Sepolia for testing with real Uniswap V2
        string memory sepoliaRpc = vm.envOr("SEPOLIA_RPC_URL", string("https://rpc.sepolia.org"));
        vm.createSelectFork(sepoliaRpc);

        // Setup accounts
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Fund test accounts with ETH
        vm.deal(owner, INITIAL_ETH_BALANCE);
        vm.deal(user1, INITIAL_ETH_BALANCE);
        vm.deal(user2, INITIAL_ETH_BALANCE);

        // Deploy KipuBankV3
        vm.prank(owner);
        kipuBank = new KipuBankV3(WITHDRAWAL_LIMIT, BANK_CAP, UNISWAP_V2_ROUTER, USDC_SEPOLIA, owner);

        console.log("KipuBankV3 deployed at:", address(kipuBank));
        console.log("USDC address:", USDC_SEPOLIA);
        console.log("Uniswap V2 Router:", UNISWAP_V2_ROUTER);
    }

    /*////////////////////////
        Constructor Tests
    ////////////////////////*/

    function test_ConstructorSetsCorrectValues() public view {
        assertEq(kipuBank.i_withdrawalLimit(), WITHDRAWAL_LIMIT);
        assertEq(kipuBank.s_bankCap(), BANK_CAP);
        assertEq(address(kipuBank.i_uniswapRouter()), UNISWAP_V2_ROUTER);
        assertEq(kipuBank.i_usdcAddress(), USDC_SEPOLIA);
        assertEq(kipuBank.owner(), owner);
    }

    function test_ConstructorRevertsWithZeroAddress() public {
        vm.expectRevert(KipuBankV3.KipuBank_ZeroAddress.selector);
        new KipuBankV3(WITHDRAWAL_LIMIT, BANK_CAP, address(0), USDC_SEPOLIA, owner);

        vm.expectRevert(KipuBankV3.KipuBank_ZeroAddress.selector);
        new KipuBankV3(WITHDRAWAL_LIMIT, BANK_CAP, UNISWAP_V2_ROUTER, address(0), owner);
    }

    /*////////////////////////
        Deposit ETH Tests
    ////////////////////////*/

    function test_DepositETHSwapsToUSDCAndCreditsUser() public {
        uint256 depositAmount = 0.1 ether;

        vm.prank(user1);
        vm.expectEmit(true, true, false, false);
        emit KipuBank_DepositMade(user1, address(0), depositAmount, 0);
        kipuBank.deposit{value: depositAmount}();

        uint256 userBalance = kipuBank.getBalanceOf(user1);
        assertGt(userBalance, 0, "User should have USDC balance after ETH deposit");
        assertEq(kipuBank.s_totalDeposits(), 1);

        console.log("ETH deposited:", depositAmount);
        console.log("USDC received:", userBalance);
    }

    function test_DepositRevertsWithZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert(KipuBank_InvalidAmount.selector);
        kipuBank.deposit{value: 0}();
    }

    function test_DepositRevertsWhenBankCapExceeded() public {
        // Set a very low bank cap
        vm.prank(owner);
        kipuBank.setBankCap(10 * 10 ** 6); // 10 USDC

        // Try to deposit ETH that would result in more USDC than cap
        vm.prank(user1);
        vm.expectRevert();
        kipuBank.deposit{value: 1 ether}();
    }

    /*////////////////////////
        Deposit Token Tests
    ////////////////////////*/

    function test_DepositUSDCDirectlyWithoutSwap() public {
        // First, user needs to get some USDC
        // We'll swap ETH for USDC directly using Uniswap
        uint256 usdcAmount = _getUSDCForUser(user1, 100 * 10 ** 6); // Get 100 USDC

        // Approve KipuBank to spend USDC
        vm.prank(user1);
        IERC20(USDC_SEPOLIA).approve(address(kipuBank), usdcAmount);

        // Deposit USDC
        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit KipuBank_DepositMade(user1, USDC_SEPOLIA, usdcAmount, usdcAmount);
        kipuBank.depositToken(USDC_SEPOLIA, usdcAmount);

        assertEq(kipuBank.getBalanceOf(user1), usdcAmount);
        assertEq(kipuBank.s_totalDeposits(), 1);
        console.log("USDC deposited directly:", usdcAmount);
    }

    function test_DepositTokenRevertsWithUnsupportedToken() public {
        address unsupportedToken = makeAddr("unsupportedToken");

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(KipuBank_TokenNotSupported.selector, unsupportedToken));
        kipuBank.depositToken(unsupportedToken, 100);
    }

    /*////////////////////////
        Withdrawal Tests
    ////////////////////////*/

    function test_WithdrawUSDC() public {
        // First deposit some ETH to get USDC
        uint256 depositAmount = 0.1 ether;
        vm.prank(user1);
        kipuBank.deposit{value: depositAmount}();

        uint256 userBalance = kipuBank.getBalanceOf(user1);
        assertGt(userBalance, 0);

        // Withdraw half of the balance
        uint256 withdrawAmount = userBalance / 2;
        uint256 initialUsdcBalance = IERC20(USDC_SEPOLIA).balanceOf(user1);

        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit KipuBank_WithdrawalMade(user1, withdrawAmount);
        kipuBank.withdraw(withdrawAmount);

        assertEq(kipuBank.getBalanceOf(user1), userBalance - withdrawAmount);
        assertEq(IERC20(USDC_SEPOLIA).balanceOf(user1), initialUsdcBalance + withdrawAmount);
        assertEq(kipuBank.s_totalWithdrawals(), 1);

        console.log("Withdrew USDC:", withdrawAmount);
    }

    function test_WithdrawRevertsWithInsufficientBalance() public {
        vm.prank(user1);
        vm.expectRevert();
        kipuBank.withdraw(100 * 10 ** 6);
    }

    function test_WithdrawRevertsWhenExceedsLimit() public {
        // Try to withdraw more than limit
        vm.prank(user1);
        vm.expectRevert();
        kipuBank.withdraw(WITHDRAWAL_LIMIT + 1);
    }

    function test_WithdrawRevertsWithZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert(KipuBank_InvalidAmount.selector);
        kipuBank.withdraw(0);
    }

    /*////////////////////////
        Owner Functions Tests
    ////////////////////////*/

    function test_OwnerCanSetBankCap() public {
        uint256 newCap = 200000 * 10 ** 6; // 200,000 USDC

        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit KipuBank_BankCapUpdated(newCap, block.timestamp);
        kipuBank.setBankCap(newCap);

        assertEq(kipuBank.s_bankCap(), newCap);
    }

    function test_NonOwnerCannotSetBankCap() public {
        vm.prank(user1);
        vm.expectRevert();
        kipuBank.setBankCap(200000 * 10 ** 6);
    }

    function test_OwnerCanAddSupportedToken() public {
        address newToken = makeAddr("newToken");

        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit KipuBank_TokenAdded(newToken, "NEW", 18);
        kipuBank.addSupportedToken(newToken, "NEW", 18);

        (bool isSupported, uint8 decimals, string memory symbol) = kipuBank.s_supportedTokens(newToken);
        assertTrue(isSupported);
        assertEq(decimals, 18);
        assertEq(symbol, "NEW");
    }

    function test_NonOwnerCannotAddSupportedToken() public {
        address newToken = makeAddr("newToken");

        vm.prank(user1);
        vm.expectRevert();
        kipuBank.addSupportedToken(newToken, "NEW", 18);
    }

    /*////////////////////////
        View Functions Tests
    ////////////////////////*/

    function test_GetBalanceReturnsCorrectBalance() public {
        vm.prank(user1);
        kipuBank.deposit{value: 0.1 ether}();

        uint256 balance = kipuBank.getBalanceOf(user1);
        assertGt(balance, 0);

        vm.prank(user1);
        assertEq(kipuBank.getBalance(), balance);
    }

    function test_GettersReturnCorrectValues() public view {
        assertEq(kipuBank.getWithdrawalLimit(), WITHDRAWAL_LIMIT);
        assertEq(kipuBank.getBankCap(), BANK_CAP);
        assertEq(kipuBank.getTotalDeposits(), 0);
        assertEq(kipuBank.getTotalWithdrawals(), 0);
        assertEq(kipuBank.getCurrentTotalBalance(), 0);
    }

    /*////////////////////////
        Integration Tests
    ////////////////////////*/

    function test_MultipleUsersCanDepositAndWithdraw() public {
        // User1 deposits ETH
        vm.prank(user1);
        kipuBank.deposit{value: 0.1 ether}();
        uint256 user1Balance = kipuBank.getBalanceOf(user1);

        // User2 deposits ETH
        vm.prank(user2);
        kipuBank.deposit{value: 0.2 ether}();
        uint256 user2Balance = kipuBank.getBalanceOf(user2);

        assertGt(user1Balance, 0);
        assertGt(user2Balance, 0);
        assertGt(user2Balance, user1Balance); // User2 deposited more

        // User1 withdraws
        vm.prank(user1);
        kipuBank.withdraw(user1Balance / 2);

        assertEq(kipuBank.getBalanceOf(user1), user1Balance / 2);
        assertEq(kipuBank.getBalanceOf(user2), user2Balance);

        console.log("User1 final balance:", kipuBank.getBalanceOf(user1));
        console.log("User2 final balance:", kipuBank.getBalanceOf(user2));
    }

    function test_BankCapIsRespected() public {
        // Set bank cap to a specific amount
        uint256 specificCap = 500 * 10 ** 6; // 500 USDC
        vm.prank(owner);
        kipuBank.setBankCap(specificCap);

        // Multiple users deposit until close to cap
        vm.prank(user1);
        kipuBank.deposit{value: 0.1 ether}();

        uint256 totalBalance = kipuBank.getCurrentTotalBalance();
        assertLe(totalBalance, specificCap);

        console.log("Current total balance:", totalBalance);
        console.log("Bank cap:", specificCap);
    }

    /*////////////////////////
        Helper Functions
    ////////////////////////*/

    /**
     * @notice Helper function to get USDC for a user by swapping ETH
     * @param user Address of the user
     * @param usdcAmount Amount of USDC to get
     * @return actualAmount Actual amount of USDC received
     */
    function _getUSDCForUser(address user, uint256 usdcAmount) internal returns (uint256 actualAmount) {
        // This is a helper that swaps ETH for USDC directly using Uniswap
        // for testing purposes
        address[] memory path = new address[](2);
        path[0] = WETH_SEPOLIA;
        path[1] = USDC_SEPOLIA;

        // Get amounts needed
        uint256[] memory amountsIn =
            IUniswapV2Router02(UNISWAP_V2_ROUTER).getAmountsIn(usdcAmount, path);
        uint256 ethNeeded = amountsIn[0];

        vm.prank(user);
        uint256[] memory amounts = IUniswapV2Router02(UNISWAP_V2_ROUTER).swapExactETHForTokens{value: ethNeeded}(
            usdcAmount, path, user, block.timestamp + 15 minutes
        );

        actualAmount = amounts[1];
    }
}

// Interface for testing
interface IUniswapV2Router02 {
    function swapExactETHForTokens(uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)
        external
        payable
        returns (uint256[] memory amounts);

    function getAmountsIn(uint256 amountOut, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}

// Custom errors for testing
error KipuBank_InvalidAmount();
error KipuBank_TokenNotSupported(address token);
