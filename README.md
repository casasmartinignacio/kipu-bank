# KipuBankV3 - Banco DeFi con Integración Uniswap V2

**Aplicación DeFi avanzada** que permite depositar cualquier token soportado por Uniswap V2, el cual es automáticamente intercambiado a USDC y acreditado en balance.

**Autor**: Martin Ignacio Casas

---

## Descripción

KipuBankV3 es un smart contract de banca descentralizada que acepta depósitos en ETH y cualquier token ERC-20 con liquidez en Uniswap V2. Todos los depósitos son automáticamente convertidos a USDC mediante swaps on-chain, y los usuarios mantienen un balance unificado en USDC.

### Versiones Legacy

- **KipuBankV1**: Versión básica con depósitos y retiros de ETH
- **KipuBankV2**: Añade soporte multi-token y oráculos Chainlink
- **KipuBankV3**: Versión actual con integración DeFi (Uniswap V2)

---

## Características Principales

### Para Usuarios

✅ **Depósitos Flexibles**
- Depositar ETH nativo
- Depositar cualquier token ERC-20 soportado por Uniswap V2
- Conversión automática a USDC

✅ **Balance Unificado**
- Todos los depósitos se acreditan en USDC
- Balance único por usuario
- Fácil tracking de valor

✅ **Retiros en USDC**
- Retirar USDC directamente
- Límites de retiro configurables
- Transferencias seguras con SafeERC20

### Para el Owner

✅ **Gestión del Banco**
- Actualizar capacidad máxima (bank cap)
- Agregar nuevos tokens soportados
- Control total del contrato

### Seguridad

✅ **Protección contra Slippage**: 1% máximo en todos los swaps
✅ **Deadline Protection**: 15 minutos para prevenir transacciones stale
✅ **Checks-Effects-Interactions**: Prevención de reentrancy
✅ **SafeERC20**: Manejo seguro de tokens no estándar
✅ **Custom Errors**: Gas-eficientes y descriptivos

---

## Arquitectura Técnica

### Integración con Uniswap V2

```
Usuario deposita Token X
    ↓
Contrato recibe Token X
    ↓
Aprueba Uniswap V2 Router
    ↓
Swap: Token X → WETH → USDC
    ↓
Valida bank cap
    ↓
Acredita USDC al balance del usuario
```

### Smart Contract

```solidity
contract KipuBankV3 is Ownable {
    using SafeERC20 for IERC20;

    // Variables inmutables
    IUniswapV2Router02 public immutable i_uniswapRouter;
    address public immutable i_usdcAddress;
    uint256 public immutable i_withdrawalLimit;

    // Estado
    uint256 public s_bankCap;
    mapping(address => uint256) public s_balances;

    // Funciones principales
    function deposit() external payable;
    function depositToken(address _token, uint256 _amount) external;
    function withdraw(uint256 _amount) external;
}
```

### Tecnologías Utilizadas

- **Solidity 0.8.26**: Lenguaje del contrato
- **OpenZeppelin**: Librerías auditadas (Ownable, SafeERC20)
- **Uniswap V2**: DEX para swaps automáticos
- **Foundry**: Testing y deployment

---

## Instalación

### Requisitos Previos

```bash
# Instalar Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Verificar instalación
forge --version
```

### Clonar e Instalar

```bash
# Clonar repositorio
git clone https://github.com/tuusuario/kipu-bank.git
cd kipu-bank

# Instalar dependencias
forge install
```

### Configurar Variables de Entorno

```bash
# Copiar template
cp .env.example .env

# Editar con tus valores
nano .env
```

Configurar en `.env`:
```bash
SEPOLIA_RPC_URL=https://rpc.sepolia.org
PRIVATE_KEY=tu_private_key
ETHERSCAN_API_KEY=tu_etherscan_api_key
```

---

## Deployment

### Compilar

```bash
forge build
```

### Deploy en Sepolia

```bash
forge script script/DeployKipuBankV3.s.sol:DeployKipuBankV3 \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  -vvvv
```

### Parámetros de Deployment

El script usa estos valores por defecto:

- **Withdrawal Limit**: 1,000 USDC
- **Bank Cap**: 100,000 USDC
- **Owner**: msg.sender (el deployer)

### Direcciones por Red

**Sepolia Testnet**:
- Uniswap V2 Router: `0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008`
- USDC: `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238`
- WETH: `0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14`

**Ethereum Mainnet**:
- Uniswap V2 Router: `0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D`
- USDC: `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48`
- WETH: `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2`

---

## Testing

### Ejecutar Tests

```bash
# Tests básicos
forge test

# Tests con logs
forge test -vv

# Tests con traces
forge test -vvv

# Coverage
forge coverage
```

### Tests Incluidos

- ✅ Constructor y validaciones
- ✅ Depósitos de ETH con swap a USDC
- ✅ Depósitos de tokens ERC-20
- ✅ Depósitos directos de USDC (sin swap)
- ✅ Retiros de USDC
- ✅ Validación de bank cap
- ✅ Funciones de owner
- ✅ Tests de integración multi-usuario

---

## Guía de Uso

### 1. Depositar ETH

```bash
cast send <CONTRACT_ADDRESS> \
  "deposit()" \
  --value 0.1ether \
  --private-key $PRIVATE_KEY \
  --rpc-url $SEPOLIA_RPC_URL
```

El contrato automáticamente:
1. Recibe 0.1 ETH
2. Swapea ETH → USDC en Uniswap V2
3. Acredita USDC a tu balance

### 2. Depositar Tokens ERC-20

**Paso 1: Aprobar el token**
```bash
cast send <TOKEN_ADDRESS> \
  "approve(address,uint256)" \
  <CONTRACT_ADDRESS> \
  <AMOUNT> \
  --private-key $PRIVATE_KEY \
  --rpc-url $SEPOLIA_RPC_URL
```

**Paso 2: Depositar**
```bash
cast send <CONTRACT_ADDRESS> \
  "depositToken(address,uint256)" \
  <TOKEN_ADDRESS> \
  <AMOUNT> \
  --private-key $PRIVATE_KEY \
  --rpc-url $SEPOLIA_RPC_URL
```

### 3. Consultar Balance

```bash
cast call <CONTRACT_ADDRESS> \
  "getBalance()" \
  --rpc-url $SEPOLIA_RPC_URL \
  --from <YOUR_ADDRESS>
```

### 4. Retirar USDC

```bash
cast send <CONTRACT_ADDRESS> \
  "withdraw(uint256)" \
  <AMOUNT_IN_USDC> \
  --private-key $PRIVATE_KEY \
  --rpc-url $SEPOLIA_RPC_URL
```

Nota: El amount debe estar en 6 decimales (USDC). Ejemplo: 100 USDC = `100000000`

### 5. Funciones de Owner

**Actualizar bank cap:**
```bash
cast send <CONTRACT_ADDRESS> \
  "setBankCap(uint256)" \
  200000000000 \
  --private-key $PRIVATE_KEY \
  --rpc-url $SEPOLIA_RPC_URL
```

**Agregar token soportado:**
```bash
cast send <CONTRACT_ADDRESS> \
  "addSupportedToken(address,string,uint8)" \
  <TOKEN_ADDRESS> \
  "SYMBOL" \
  18 \
  --private-key $PRIVATE_KEY \
  --rpc-url $SEPOLIA_RPC_URL
```

---

## Funciones del Contrato

### Funciones Públicas

#### `deposit()`
Deposita ETH y recibe USDC en balance.
- **Payable**: Sí
- **Validaciones**: amount > 0, bank cap no excedido

#### `depositToken(address _token, uint256 _amount)`
Deposita token ERC-20 y recibe USDC en balance.
- **Requisitos**: Token soportado, aprobación previa
- **Comportamiento**: Si es USDC → acredita directo, sino → swap a USDC

#### `withdraw(uint256 _amount)`
Retira USDC del balance.
- **Validaciones**: amount > 0, <= withdrawal limit, balance suficiente
- **Transfers**: USDC directamente al usuario

### Funciones de Owner

#### `setBankCap(uint256 _newBankCap)`
Actualiza la capacidad máxima del banco en USDC.

#### `addSupportedToken(address _token, string _symbol, uint8 _decimals)`
Agrega un nuevo token a la lista de tokens soportados.

### Funciones de Consulta

- `getBalance()`: Balance del caller en USDC
- `getBalanceOf(address _user)`: Balance de un usuario específico
- `getWithdrawalLimit()`: Límite de retiro
- `getBankCap()`: Capacidad máxima
- `getTotalDeposits()`: Total de depósitos realizados
- `getTotalWithdrawals()`: Total de retiros realizados
- `getCurrentTotalBalance()`: Balance total actual en USDC

---

## Eventos

```solidity
event KipuBank_DepositMade(
    address indexed user,
    address indexed tokenIn,
    uint256 amountIn,
    uint256 usdcReceived
);

event KipuBank_WithdrawalMade(
    address indexed user,
    uint256 amount
);

event KipuBank_BankCapUpdated(
    uint256 newCap,
    uint256 timestamp
);

event KipuBank_TokenAdded(
    address indexed token,
    string symbol,
    uint8 decimals
);
```

---

## Errores Personalizados

```solidity
error KipuBank_InvalidAmount();
error KipuBank_WithdrawalLimitExceeded(uint256 requested, uint256 allowed);
error KipuBank_InsufficientBalance(uint256 available, uint256 requested);
error KipuBank_BankCapacityExceeded(uint256 remainingCapacity);
error KipuBank_TokenNotSupported(address token);
error KipuBank_SwapFailed();
error KipuBank_DeadlineExpired();
error KipuBank_ZeroAddress();
```

---

## Decisiones de Diseño

### 1. Balance Único en USDC

**Decisión**: Todos los usuarios tienen balance únicamente en USDC (6 decimales).

**Razones**:
- Simplifica la contabilidad del contrato
- Bank cap fácil de validar sin oráculos
- Usuarios conocen el valor exacto de sus fondos
- Modelo estándar en DeFi (savings account)

### 2. Path de Swap: Token → WETH → USDC

**Decisión**: Usar WETH como token intermediario en swaps.

**Razones**:
- Mayor liquidez en pares Token/WETH
- Reduce slippage
- Path estándar en Uniswap V2

```solidity
path[0] = tokenIn;
path[1] = WETH;
path[2] = USDC;
```

### 3. Slippage Fijo del 1%

**Decisión**: Tolerancia de slippage fija del 1%.

**Razones**:
- Balance entre protección y flexibilidad
- Previene front-running
- Simple de implementar

**Cálculo**:
```solidity
uint256 minAmountOut = (expectedOutput * 9900) / 10000;
```

### 4. Deadline de 15 Minutos

**Decisión**: Todas las transacciones con deadline de 15 minutos.

**Razones**:
- Previene ejecución tardía
- Estándar de la industria
- Balance entre seguridad y usabilidad

### 5. Uniswap V2 vs V3/V4

**Decisión**: Usar Uniswap V2.

**Razones**:
- Simplicidad de integración
- Router único bien documentado
- Apropiado para nivel educativo del curso
- Amplia disponibilidad en testnets

---

## Patrones de Seguridad

### Checks-Effects-Interactions (CEI)

```solidity
function withdraw(uint256 _amount) external {
    // CHECKS
    if (_amount > i_withdrawalLimit) revert...
    if (s_balances[msg.sender] < _amount) revert...

    // EFFECTS
    s_balances[msg.sender] -= _amount;
    s_currentTotalBalance -= _amount;

    // INTERACTIONS
    IERC20(i_usdcAddress).safeTransfer(msg.sender, _amount);
}
```

### SafeERC20

Todas las operaciones con tokens usan `SafeERC20` para manejar tokens no estándar:

```solidity
IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
IERC20(_token).safeIncreaseAllowance(address(i_uniswapRouter), _amount);
```

### Protección contra Slippage

```solidity
uint256[] memory amountsOut = i_uniswapRouter.getAmountsOut(_amountIn, path);
uint256 expectedUsdcOut = amountsOut[amountsOut.length - 1];
uint256 minAmountOut = (expectedUsdcOut * 9900) / 10000; // 1% slippage
```

### Validación de Outputs

```solidity
if (usdcReceived == 0) revert KipuBank_SwapFailed();
```

---

## Estructura del Proyecto

```
kipu-bank/
├── src/
│   ├── KipuBankV1.sol          # Versión legacy
│   ├── KipuBankV2.sol          # Versión legacy
│   └── KipuBankV3.sol          # Versión actual
│
├── test/
│   └── KipuBankV3.t.sol        # Tests completos
│
├── script/
│   └── DeployKipuBankV3.s.sol  # Script de deployment
│
├── lib/                         # Dependencias (Foundry)
│   ├── openzeppelin-contracts/
│   ├── v2-core/
│   ├── v2-periphery/
│   └── forge-std/
│
├── README.md                    # Este archivo
├── .env.example                 # Template de variables
├── .gitignore
└── foundry.toml                 # Configuración Foundry
```

---

## Mejoras de V3 vs V2

| Aspecto | KipuBankV2 | KipuBankV3 |
|---------|------------|------------|
| **Tokens soportados** | ETH, tokens pre-aprobados | Cualquier token con liquidez Uniswap V2 |
| **Conversión** | Manual por usuario | Automática a USDC |
| **Balance** | Multi-token (mapping anidado) | Único en USDC |
| **Bank cap** | En ETH (requiere oracle) | En USDC (sin oracle) |
| **Integración DeFi** | No | Sí (Uniswap V2) |
| **Oracle** | Chainlink (ETH/USD) | No necesario |
| **Complejidad** | Media | Media-Alta |

---

## Recursos

### Documentación Externa
- [Uniswap V2 Docs](https://docs.uniswap.org/contracts/v2/overview)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)
- [Foundry Book](https://book.getfoundry.sh/)
- [Solidity Docs](https://docs.soliditylang.org/)

### Block Explorers
- [Sepolia Etherscan](https://sepolia.etherscan.io/)
- [Ethereum Mainnet Etherscan](https://etherscan.io/)

---

## Licencia

MIT License

---

## Autor

**Martin Ignacio Casas**

---

## Agradecimientos

- EthKipu por el programa educativo
- OpenZeppelin por contratos auditados
- Uniswap por el protocolo DEX
- Foundry por herramientas de desarrollo
- La comunidad Ethereum
