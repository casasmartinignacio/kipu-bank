# KipuBank Smart Contract

## Project Description

KipuBank is a secure smart contract that allows users to deposit and withdraw ETH into personal vaults with built-in safety limits. This project was developed as part of Practical Work 2 of the Ethereum Developer Pack, demonstrating fundamental Solidity concepts and security best practices.

The contract implements a simple banking system where each user has their own vault to store ETH. It includes withdrawal limits per transaction and a global bank capacity to ensure controlled growth and security.

## Features

- **Personal Vaults**: Each user has their own balance stored securely on-chain
- **Deposit Functionality**: Users can deposit ETH into their personal vault
- **Withdrawal Limits**: Fixed maximum amount that can be withdrawn per transaction
- **Bank Capacity**: Global limit on total deposits to control contract size
- **Transaction Tracking**: Keeps count of total deposits and withdrawals
- **Security Patterns**: Implements checks-effects-interactions and pull-over-push patterns
- **Custom Errors**: Gas-efficient error handling
- **Events**: Emits events for all state changes

## Contract Variables

### Immutable
- `i_withdrawalLimit`: Maximum amount that can be withdrawn in a single transaction (set at deployment)

### State Variables
- `s_bankCap`: Maximum total ETH the bank can hold
- `s_balances`: Mapping of user addresses to their vault balances
- `s_totalDeposits`: Counter for total number of deposits made
- `s_totalWithdrawals`: Counter for total number of withdrawals made
- `s_currentTotalBalance`: Current total balance held in the contract

## Functions

### External Functions

#### `deposit()`
Allows users to deposit ETH into their personal vault.
- **Payable**: Yes
- **Requirements**:
  - Amount must be greater than 0
  - Total bank balance after deposit must not exceed bank capacity
- **Effects**:
  - Increases user's balance
  - Increments deposit counter
  - Emits `KipuBank_DepositMade` event

#### `withdraw(uint256 _amount)`
Allows users to withdraw ETH from their vault.
- **Parameters**: `_amount` - Amount of ETH to withdraw
- **Requirements**:
  - Amount must be greater than 0
  - Amount must not exceed withdrawal limit
  - User must have sufficient balance
- **Effects**:
  - Decreases user's balance
  - Increments withdrawal counter
  - Transfers ETH to user
  - Emits `KipuBank_WithdrawalMade` event

### View Functions

#### `getBalance()`
Returns the caller's current vault balance.
- **Returns**: User's balance in wei

#### `getWithdrawalLimit()`
Returns the maximum amount that can be withdrawn per transaction.
- **Returns**: Withdrawal limit in wei

#### `getBankCap()`
Returns the maximum capacity of the bank.
- **Returns**: Bank capacity in wei

#### `getTotalDeposits()`
Returns the total number of deposits made.
- **Returns**: Total deposit count

#### `getTotalWithdrawals()`
Returns the total number of withdrawals made.
- **Returns**: Total withdrawal count

#### `getContractBalance()`
Returns the contract's current total ETH balance.
- **Returns**: Contract balance in wei

## Custom Errors

- `KipuBank_InvalidAmount()`: Thrown when amount is zero
- `KipuBank_WithdrawalLimitExceeded(uint256 requestedAmount, uint256 allowedLimit)`: Thrown when withdrawal exceeds limit
- `KipuBank_InsufficientBalance(uint256 availableBalance, uint256 requestedAmount)`: Thrown when user doesn't have enough balance
- `KipuBank_BankCapacityExceeded(uint256 remainingCapacity)`: Thrown when deposit would exceed bank capacity
- `KipuBank_TransferFailed(bytes error)`: Thrown when ETH transfer fails

## Events

- `KipuBank_DepositMade(address indexed user, uint256 amount)`: Emitted on successful deposit
- `KipuBank_WithdrawalMade(address indexed user, uint256 amount)`: Emitted on successful withdrawal

## Deployment Instructions

### Prerequisites
- Node.js and npm installed
- Hardhat or Foundry framework
- Testnet ETH (Sepolia, Goerli, etc.)
- MetaMask or similar wallet

### Deployment Parameters

When deploying the contract, you need to provide two parameters:
1. `_withdrawalLimit`: Maximum amount (in wei) that can be withdrawn per transaction
2. `_bankCap`: Maximum total capacity (in wei) the bank can hold

Example values:
- Withdrawal limit: 1 ETH = 1000000000000000000 wei
- Bank capacity: 10 ETH = 10000000000000000000 wei

### Using Hardhat

1. Clone the repository:
```bash
git clone https://github.com/yourusername/kipu-bank.git
cd kipu-bank
```

2. Install dependencies:
```bash
npm install --save-dev hardhat @nomicfoundation/hardhat-toolbox
```

3. Create a deployment script in `scripts/deploy.js`:
```javascript
const hre = require("hardhat");

async function main() {
  const withdrawalLimit = hre.ethers.parseEther("1"); // 1 ETH
  const bankCap = hre.ethers.parseEther("10"); // 10 ETH

  const KipuBank = await hre.ethers.getContractFactory("KipuBank");
  const kipuBank = await KipuBank.deploy(withdrawalLimit, bankCap);

  await kipuBank.waitForDeployment();

  console.log("KipuBank deployed to:", await kipuBank.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
```

4. Deploy to testnet:
```bash
npx hardhat run scripts/deploy.js --network sepolia
```

## How to Interact with the Contract

### Using Remix IDE

1. Go to [Remix IDE](https://remix.ethereum.org)
2. Create a new file `KipuBank.sol` and paste the contract code
3. Compile with Solidity version 0.8.26
4. Deploy or connect to existing contract
5. Use the interface to interact with functions

### Making a Deposit

1. Select the `deposit` function
2. Enter the amount of ETH in the "VALUE" field
3. Click "transact"
4. Confirm the transaction in your wallet

### Making a Withdrawal

1. Select the `withdraw` function
2. Enter the amount to withdraw in wei (e.g., 100000000000000000 for 0.1 ETH)
3. Click "transact"
4. Confirm the transaction in your wallet

### Checking Your Balance

1. Click the `getBalance` button
2. The function will return your current vault balance in wei

### Example Interaction Flow

```javascript
// Connect to contract
const kipuBank = await ethers.getContractAt("KipuBank", contractAddress);

// Deposit 0.5 ETH
await kipuBank.deposit({ value: ethers.parseEther("0.5") });

// Check balance
const balance = await kipuBank.getBalance();
console.log("Balance:", ethers.formatEther(balance), "ETH");

// Withdraw 0.2 ETH
await kipuBank.withdraw(ethers.parseEther("0.2"));

// Check withdrawal limit
const limit = await kipuBank.getWithdrawalLimit();
console.log("Withdrawal limit:", ethers.formatEther(limit), "ETH");
```

## Security Considerations

This contract implements several security best practices:

- **Checks-Effects-Interactions Pattern**: State changes happen before external calls
- **Pull Over Push**: Users withdraw funds rather than receiving automatic transfers
- **Custom Errors**: More gas-efficient than `require` with string messages
- **Input Validation**: All inputs are validated through modifiers and checks
- **Immutable Variables**: Critical values are set once at deployment
- **Private Functions**: Internal logic is separated and protected

## Testing Recommendations

Before interacting with the contract:
1. Test all functions on a testnet first
2. Verify the contract code on a block explorer
3. Start with small amounts
4. Confirm withdrawal limit and bank capacity values
5. Check all getter functions return expected values

## Author

**Martin Ignacio Casas**

## License

This project is licensed under the MIT License.

## Future Improvements

As part of the Ethereum Developer Pack curriculum, this contract will be extended in future modules with additional features such as:
- Interest calculation
- Multi-signature withdrawals
- Time-locked deposits
- Admin functions
- Upgradability patterns
