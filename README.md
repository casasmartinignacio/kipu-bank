# KipuBankV2 Smart Contract

## Project Description

KipuBankV2 is an advanced smart contract that allows users to securely deposit and withdraw both ETH and ERC-20 tokens. This project represents the evolution of KipuBank, developed as the final exam for Module 3 of the Ethereum Developer Pack.

The contract implements multi-token support, Chainlink price feeds for real-time ETH/USD conversion, and role-based access control following the concepts learned in the course.

## Key Improvements from V1

### 1. **Multi-Token Support**
- Support for native ETH and multiple ERC-20 tokens
- Uses `address(0)` to represent native ETH
- Separate deposit/withdraw functions for tokens
- Nested mapping structure for multi-token accounting

### 2. **Chainlink Oracle Integration**
- Real-time ETH/USD price feeds via Chainlink Data Feeds
- Stale price protection with heartbeat validation
- Oracle compromise detection
- Functions to view balances and bank cap in USD

### 3. **Access Control**
- Inherits from OpenZeppelin's `Ownable` contract
- Owner-only functions for critical operations:
  - Update bank capacity (in ETH or USD)
  - Add new supported tokens
  - Update oracle feed address

### 4. **Security Patterns**
- **SafeERC20**: Prevents issues with non-standard ERC-20 tokens
- **Checks-Effects-Interactions**: Prevents reentrancy attacks
- **Custom Errors**: Gas-efficient error handling

### 5. **Decimal Conversion**
- Normalizes all values to 6 decimals (USDC standard)
- Handles ETH (18 decimals) and oracle prices (8 decimals)
- Accurate conversion functions for ETH to USD

### 6. **Type Declarations**
- `TokenInfo` struct to manage supported tokens
- Organized state variables with clear naming conventions
- Constants for oracle heartbeat and decimal factors

## Contract Architecture

### Inheritance
```
KipuBankV2 is Ownable
```
- Inherits access control from OpenZeppelin

### Libraries Used
- **SafeERC20**: Safe token transfer operations
- **OpenZeppelin Ownable**: Access control
- **Chainlink AggregatorV3Interface**: Price feed integration

### Constants
- `ORACLE_HEARTBEAT`: 3600 seconds (1 hour) - maximum staleness for oracle data
- `DECIMAL_FACTOR`: 1e20 - converts from 26 decimals (18+8) to 6 decimals
- `NATIVE_TOKEN`: address(0) - represents native ETH

## Features

### For Users
- Deposit ETH into personal vault
- Deposit supported ERC-20 tokens
- Withdraw ETH (with limits)
- Withdraw ERC-20 tokens
- View balance in native token or USD equivalent

### For Owner
- Update bank capacity (in ETH or USD)
- Add new supported tokens
- Update Chainlink price feed address

## Contract Variables

### Immutable
- `i_withdrawalLimit`: Maximum amount that can be withdrawn in a single transaction

### State Variables
- `s_bankCap`: Maximum total ETH the bank can hold
- `s_ethUsdFeed`: Chainlink ETH/USD price feed interface
- `s_balances`: Nested mapping of user balances per token
- `s_supportedTokens`: Mapping of token addresses to TokenInfo
- `s_totalDeposits`: Counter for total deposits
- `s_totalWithdrawals`: Counter for total withdrawals
- `s_currentTotalBalance`: Current total balance in ETH

## Functions Reference

### User Functions

#### `deposit()`
Deposit ETH into your vault.
- **Payable**: Yes
- **Requirements**: Amount > 0, within bank capacity

#### `depositToken(address _token, uint256 _amount)`
Deposit ERC-20 tokens into your vault.
- **Requirements**: Token must be supported, amount > 0
- **Note**: Must approve contract to spend tokens first

#### `withdraw(uint256 _amount)`
Withdraw ETH from your vault.
- **Requirements**: Amount > 0, within withdrawal limit, sufficient balance

#### `withdrawToken(address _token, uint256 _amount)`
Withdraw ERC-20 tokens from your vault.
- **Requirements**: Token supported, amount > 0, sufficient balance

### Owner Functions

#### `setBankCap(uint256 _newBankCap)`
Update bank capacity in ETH.

#### `setBankCapInUSD(uint256 _capInUsd)`
Update bank capacity based on USD value (automatically converts using oracle).

#### `setEthUsdFeed(address _newFeed)`
Update the Chainlink price feed address.

#### `addSupportedToken(address _token, string _symbol, uint8 _decimals)`
Add a new token to the supported list.

### View Functions

#### `getBalance()` / `getBalance(address _token)`
Get your balance in ETH or specific token.

#### `getUserBalanceInUsd(address _user)`
Get a user's ETH balance converted to USD.

#### `getBankCapInUsd()`
Get bank capacity in USD.

#### `getEthUsdPrice()`
Get current ETH/USD price from Chainlink (8 decimals).

#### `convertEthToUsd(uint256 _ethAmount)`
Convert any ETH amount to USD (6 decimals).

## Events

- `KipuBank_DepositMade(address indexed user, uint256 amount, uint256 usdValue)`
- `KipuBank_WithdrawalMade(address indexed user, uint256 amount, uint256 usdValue)`
- `KipuBank_TokenDeposit(address indexed user, address indexed token, uint256 amount, uint256 usdValue)`
- `KipuBank_TokenWithdrawal(address indexed user, address indexed token, uint256 amount, uint256 usdValue)`
- `KipuBank_BankCapUpdated(uint256 newCap, uint256 timestamp)`
- `KipuBank_EthUsdFeedUpdated(address newFeed)`
- `KipuBank_TokenAdded(address indexed token, string symbol, uint8 decimals)`

## Custom Errors

- `KipuBank_InvalidAmount()`: Amount is zero
- `KipuBank_WithdrawalLimitExceeded(uint256 requested, uint256 allowed)`
- `KipuBank_InsufficientBalance(uint256 available, uint256 requested)`
- `KipuBank_BankCapacityExceeded(uint256 remainingCapacity)`
- `KipuBank_TransferFailed(bytes error)`
- `KipuBank_OracleCompromised()`: Oracle returned invalid price
- `KipuBank_StalePrice()`: Oracle data is outdated
- `KipuBank_TokenNotSupported(address token)`

## Deployment Instructions

### Prerequisites
- Foundry installed (`curl -L https://foundry.paradigm.xyz | bash && foundryup`)
- Testnet ETH (Sepolia recommended)
- MetaMask or similar wallet

### Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/kipu-bank.git
cd kipu-bank
```

2. Install dependencies:
```bash
forge install OpenZeppelin/openzeppelin-contracts --no-commit
forge install smartcontractkit/chainlink --no-commit
```

### Deployment Parameters

When deploying KipuBankV2, you need these parameters:

1. `_withdrawalLimit`: Maximum withdrawal per transaction (in wei)
2. `_bankCap`: Maximum bank capacity (in wei)
3. `_ethUsdFeed`: Chainlink ETH/USD price feed address for your network
4. `_owner`: Address that will own the contract

#### Chainlink Price Feed Addresses

**Sepolia Testnet**:
- ETH/USD: `0x694AA1769357215DE4FAC081bf1f309aDC325306`

**Ethereum Mainnet**:
- ETH/USD: `0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419`

Find more feeds at: https://docs.chain.link/data-feeds/price-feeds/addresses

### Deployment Script Example

Create `script/DeployKipuBankV2.s.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {KipuBankV2} from "../src/KipuBankV2.sol";

contract DeployKipuBankV2 is Script {
    function run() external returns (KipuBankV2) {
        uint256 withdrawalLimit = 1 ether;
        uint256 bankCap = 100 ether;
        address ethUsdFeed = 0x694AA1769357215DE4FAC081bf1f309aDC325306; // Sepolia
        address owner = msg.sender;

        vm.startBroadcast();
        KipuBankV2 kipuBank = new KipuBankV2(
            withdrawalLimit,
            bankCap,
            ethUsdFeed,
            owner
        );
        vm.stopBroadcast();

        return kipuBank;
    }
}
```

Deploy to Sepolia:
```bash
forge script script/DeployKipuBankV2.s.sol:DeployKipuBankV2 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

## How to Interact

### Depositing ETH

```bash
cast send <CONTRACT_ADDRESS> "deposit()" --value 0.1ether --private-key $PRIVATE_KEY --rpc-url $RPC_URL
```

### Depositing ERC-20 Tokens

1. First, approve the contract:
```bash
cast send <TOKEN_ADDRESS> "approve(address,uint256)" <CONTRACT_ADDRESS> 1000000 --private-key $PRIVATE_KEY --rpc-url $RPC_URL
```

2. Then deposit:
```bash
cast send <CONTRACT_ADDRESS> "depositToken(address,uint256)" <TOKEN_ADDRESS> 1000000 --private-key $PRIVATE_KEY --rpc-url $RPC_URL
```

### Withdrawing ETH

```bash
cast send <CONTRACT_ADDRESS> "withdraw(uint256)" 100000000000000000 --private-key $PRIVATE_KEY --rpc-url $RPC_URL
```

### Checking Balance

```bash
cast call <CONTRACT_ADDRESS> "getBalance()" --rpc-url $RPC_URL
```

### Checking Balance in USD

```bash
cast call <CONTRACT_ADDRESS> "getUserBalanceInUsd(address)" <YOUR_ADDRESS> --rpc-url $RPC_URL
```

### Owner Operations

Add supported token:
```bash
cast send <CONTRACT_ADDRESS> "addSupportedToken(address,string,uint8)" <TOKEN_ADDRESS> "USDC" 6 --private-key $PRIVATE_KEY --rpc-url $RPC_URL
```

Update bank cap in USD:
```bash
cast send <CONTRACT_ADDRESS> "setBankCapInUSD(uint256)" 100000000000 --private-key $PRIVATE_KEY --rpc-url $RPC_URL
```

## Design Decisions and Trade-offs

### 1. Using address(0) for Native ETH
**Decision**: Represent ETH as `address(0)` in the token mappings.

**Reasoning**: Allows unified storage structure for both ETH and ERC-20 tokens without duplicating logic.

**Trade-off**: Slightly less intuitive for developers unfamiliar with this pattern, but it's a common industry practice.

### 2. Normalizing to 6 Decimals
**Decision**: Convert all USD values to 6 decimals (USDC standard).

**Reasoning**:
- ETH has 18 decimals
- Chainlink feeds have 8 decimals
- USDC (most common stablecoin) has 6 decimals
- Standardizing to 6 decimals prevents overflow and aligns with DeFi standards

**Trade-off**: Less precision than maintaining 18 decimals, but sufficient for financial applications and reduces overflow risk.

### 3. Ownable vs. AccessControl
**Decision**: Use OpenZeppelin's `Ownable` instead of `AccessControl`.

**Reasoning**: For this contract, we only need owner/admin functions. `Ownable` is simpler and more gas-efficient.

**Trade-off**: If we later need multiple roles (e.g., admin, treasury, moderator), we'd need to migrate to `AccessControl`.

### 4. Oracle Heartbeat Validation
**Decision**: Implement 1-hour staleness check for Chainlink data.

**Reasoning**: Prevents using outdated prices that could be exploited.

**Trade-off**: Contract may fail during extreme network congestion if oracle doesn't update within 1 hour. Owner can update feed address if needed.

### 5. Mutable Oracle Address
**Decision**: Make `s_ethUsdFeed` mutable (not immutable).

**Reasoning**: Chainlink may deprecate or upgrade feeds. Owner can update without redeploying entire contract.

**Trade-off**: Introduces centralization risk if owner is compromised. Mitigated by using a multisig wallet as owner.

### 6. Simplified Token USD Valuation
**Decision**: Token deposits show 0 USD value in events.

**Reasoning**: Each token would require its own Chainlink oracle, significantly increasing complexity and gas costs.

**Trade-off**: Less informative events for ERC-20 deposits. Future versions could add token-specific oracles as needed.

### 7. SafeERC20 for All Token Operations
**Decision**: Always use SafeERC20's `safeTransfer` and `safeTransferFrom`.

**Reasoning**: Some ERC-20 tokens don't return boolean values or revert on failure (e.g., USDT). SafeERC20 handles these edge cases.

**Trade-off**: Slightly higher gas costs, but much safer for production use.

## Security Considerations

### Implemented Patterns
1. **Checks-Effects-Interactions**: All state changes before external calls
2. **Pull Over Push**: Users withdraw rather than receiving automatic transfers
3. **Custom Errors**: Gas-efficient error handling
4. **SafeERC20**: Handles non-standard token implementations
5. **Oracle Validation**: Checks for stale and compromised price data
6. **Access Control**: Owner-only functions for critical operations

### Recommendations for Production
1. **Use a Multisig Wallet as Owner**: Prevents single point of failure
2. **Gradual Rollout**: Start with low bank cap and increase gradually
3. **Monitor Oracle Health**: Set up alerts for oracle failures
4. **Regular Security Audits**: Have code reviewed by professional auditors
5. **Bug Bounty Program**: Incentivize white-hat hackers to find vulnerabilities
6. **Comprehensive Testing**: Unit tests, integration tests, and fuzzing

## Testing

Create tests in `test/KipuBankV2.t.sol`:

```bash
forge test
```

Run with verbosity:
```bash
forge test -vvv
```

Check coverage:
```bash
forge coverage
```

## Author

**Martin Ignacio Casas**

Ethereum Developer Pack - Module 3 Final Project

## License

This project is licensed under the MIT License.

## Acknowledgments

- OpenZeppelin for secure, audited smart contract libraries
- Chainlink for decentralized oracle infrastructure
- EthKipu for comprehensive Solidity education

---

**Note**: This contract is for educational purposes and part of a course final project. While it implements production-level patterns, additional testing and auditing would be required before mainnet deployment with real funds.
