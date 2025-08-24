# 🌊 Protego.ai on Sei Network

**Revolutionary Invoice Financing Platform Powered by Sei's Lightning-Fast Blockchain**

[![Sei Network](https://img.shields.io/badge/Sei-Network-blue)](https://sei.io)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.19-blue)](https://soliditylang.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

---

## 🚀 Overview

Protego.ai transforms traditional invoice financing by leveraging Sei Network's sub-second finality and advanced DeFi protocols. Our platform enables businesses to tokenize invoices as NFTs and allows investors to earn yield by funding working capital needs.

### ⚡ Why Sei Network?

- **Sub-second Finality**: Lightning-fast transaction confirmation
- **Twin-Turbo Consensus**: Parallel execution for optimal performance
- **Native Order Matching**: Built for DeFi protocols
- **EVM Compatibility**: Seamless smart contract deployment
- **High Throughput**: Handle multiple simultaneous investors

---

## 🏗️ Architecture

### Token Standards Implementation

| Standard | Usage | Contract |
|----------|-------|----------|
| **ERC-721** | Unique Invoice NFTs | `ProtegoInvoiceNFT` |
| **ERC-4626** | Yield-Bearing Vaults | `ProtegoYieldVault` |
| **ERC-1155** | Multi-Invoice Notes | `ProtegoMultiInvoiceNotes` |
| **ERC-20** | USDC Stablecoin | `MockERC20` (testnet) |

### Core Components

```
📦 Protego.ai Ecosystem
├── 🏦 ProtegoMasterVault (Coordination Hub)
├── 🎫 ProtegoInvoiceNFT (ERC-721 Invoice Tokens)
├── 💰 ProtegoYieldVault (ERC-4626 Investment Vaults)
├── 🎭 ProtegoMultiInvoiceNotes (ERC-1155 Fractionalized Notes)
├── 📈 ProtegoYieldStrategy (Automated Yield Generation)
└── 🔧 Supporting Infrastructure
```

---

## 🛠️ Quick Start

### Prerequisites

- **Node.js**: >= 16.0.0
- **npm**: >= 8.0.0
- **Git**: Latest version

### 1. Clone & Install

```bash
git clone https://github.com/protego-ai/sei-contracts.git
cd sei-contracts
chmod +x build.sh
```

### 2. One-Command Demo

```bash
# Run complete demo on local network
./build.sh localhost false true
```

### 3. Deploy to Sei Testnet

```bash
# Setup environment
cp .env.example .env
# Edit .env with your private key

# Deploy to testnet
./build.sh seiTestnet false true
```

---

## 📋 Environment Setup

### Create `.env` File

```bash
# Sei Network Configuration
PRIVATE_KEY=your_private_key_here
TREASURY_ADDRESS=your_treasury_address

# API Keys (optional)
SEI_API_KEY=your_sei_explorer_api_key
COINMARKETCAP_API_KEY=your_cmc_api_key

# RPC URLs (defaults provided)
SEI_MAINNET_RPC=https://evm-rpc.sei-apis.com
SEI_TESTNET_RPC=https://evm-rpc-testnet.sei-apis.com
```

### Get Testnet SEI

1. Visit [Sei Testnet Faucet](https://faucet.sei-apis.com/)
2. Enter your wallet address
3. Receive testnet SEI tokens

---

## 🎯 Usage Examples

### Deploy Contracts

```bash
# Local development
npm run deploy:local

# Sei Testnet
npm run deploy:testnet

# Sei Mainnet (production)
npm run deploy:mainnet
```

### Run Simulation

```bash
# Complete simulation demo
npm run demo

# Testnet simulation
npm run simulate:testnet
```

### Custom Hardhat Tasks

```bash
# Check Sei network status
npx hardhat sei-status --network seiTestnet

# Estimate deployment costs
npx hardhat estimate-costs

# Fund test accounts
npx hardhat fund-accounts --amount 10
```

---

## 💼 Business Flow

### 1. Invoice Creation (ERC-721)
```solidity
// Marina creates an invoice NFT
function createInvoiceAndVault(
    address debtor,        // Fashion Inc
    uint256 faceValue,     // $500,000
    uint256 discountRate,  // 10% (1000 basis points)
    uint256 maturityDays,  // 90 days
    // ... additional parameters
) external returns (uint256 invoiceTokenId, address vaultAddress)
```

### 2. Investor Funding (ERC-4626)
```solidity
// Investors deposit USDC into yield vault
function deposit(uint256 assets, address receiver) 
    external returns (uint256 shares)
```

### 3. Yield Generation
```solidity
// Automated yield distribution
function executeYieldStrategy() external onlyOwner
```

### 4. Settlement & Withdrawal
```solidity
// Investors redeem shares for principal + yield
function redeem(uint256 shares, address receiver, address owner) 
    external returns (uint256 assets)
```

---

## 📊 Performance Metrics

### Sei Network Optimizations

| Metric | Traditional | Sei Network | Improvement |
|--------|------------|-------------|-------------|
| Block Time | 12-15 seconds | 600ms | **25x faster** |
| Finality | 12+ blocks | Sub-second | **240x faster** |
| Gas Costs | High | Ultra-low | **90% reduction** |
| Throughput | Limited | High | **10x capacity** |

### Yield Performance

- **Base APY**: 24% (2% monthly)
- **Sei Multiplier**: 1.5x (network efficiency bonus)
- **Effective APY**: 36% 
- **Compound Frequency**: Daily (enabled by fast blocks)

---

## 🔧 Development

### Project Structure

```
protego-sei/
├── contracts/              # Smart contracts
│   ├── ProtegoMasterVault.sol
│   ├── ProtegoInvoiceNFT.sol
│   ├── ProtegoYieldVault.sol
│   └── ProtegoMultiInvoiceNotes.sol
├── scripts/                # Deployment scripts
│   ├── deploy-sei.js
│   └── simulate-protego.js
├── test/                   # Test files
├── deployments/            # Deployment records
├── hardhat.config.js       # Hardhat configuration
└── build.sh               # Build script
```

### Testing

```bash
# Run all tests
npm run test

# Generate coverage report
npm run coverage

# Gas usage report
npm run gas-report
```

### Code Quality

```bash
# Lint contracts
npm run lint

# Format code
npm run format

# Analyze contract sizes
npm run size-contracts
```

---

## 🌐 Network Configuration

### Sei Mainnet (Production)
- **Chain ID**: 1329
- **RPC URL**: https://evm-rpc.sei-apis.com
- **Explorer**: https://seistream.app
- **Currency**: SEI

### Sei Testnet (Development)
- **Chain ID**: 713715  
- **RPC URL**: https://evm-rpc-testnet.sei-apis.com
- **Explorer**: https://seistream.app/testnet
- **Faucet**: https://faucet.sei-apis.com

---

## 📈 Advanced Features

### Multi-Invoice Portfolios (ERC-1155)

Create fractionalized investment products combining multiple invoices:

```solidity
function createNoteType(
    string memory name,           // "Q4 2024 Textile Portfolio"
    uint256[] memory invoiceIds,  // [1, 2, 3, 4]
    uint256 minimumPurchase,      // $1,000 minimum
    uint256 pricePerUnit         // $1 per note
) external returns (uint256 noteTypeId)
```

### Automated Yield Strategies

- **40%** Liquidity Pools (Sei native DEXs)
- **35%** Lending Protocols  
- **20%** SEI Staking Rewards
- **5%** Reserve Buffer

### Real-time Analytics

Monitor platform performance with built-in metrics:

```solidity
function getPlatformStats() external view returns (
    uint256 totalInvoices,
    uint256 totalValueLocked,
    uint256 totalYieldGenerated
)
```

---

## 🔒 Security Features

### Access Controls
- **Role-based permissions** using OpenZeppelin's `Ownable`
- **Multi-signature treasury** for production deployments
- **Pausable contracts** for emergency situations

### Risk Management
- **Diversified yield strategies** across multiple protocols
- **Reserve buffers** for unexpected market conditions  
- **Automatic liquidation** for defaulted invoices

### Audit Recommendations
- Get professional audit before mainnet launch
- Implement governance mechanisms for upgrades
- Set up monitoring and alerting systems

---

## 📚 Documentation

### Contract Interfaces

Each contract implements standard interfaces for maximum compatibility:

- **IERC721**: Standard NFT functionality
- **IERC4626**: Tokenized vault standard
- **IERC1155**: Multi-token standard
- **IERC20**: Basic token functionality

### Event Monitoring

Key events to monitor in production:

```solidity
event InvoiceCreated(uint256 indexed tokenId, ...);
event InvestmentMade(uint256 indexed tokenId, ...);  
event YieldGenerated(uint256 amount, uint256 timestamp);
event InvoiceMatured(uint256 tokenId, uint256 maturityDate);
```

---

## 🤝 Contributing

We welcome contributions! Here's how to get started:

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

### Development Guidelines

- Follow Solidity style guide
- Write comprehensive tests
- Update documentation
- Use conventional commit messages

---

## 🎯 Roadmap

### Phase 1: Foundation ✅
- [x] Core contract development
- [x] Sei Network integration
- [x] Basic yield strategies
- [x] Testing suite

### Phase 2: Enhancement (Q1 2024)
- [ ] Advanced yield optimization
- [ ] Governance token launch  
- [ ] Multi-chain expansion
- [ ] Mobile application

### Phase 3: Scale (Q2 2024)
- [ ] Enterprise partnerships
- [ ] Institutional investor portal
- [ ] Real-time credit scoring
- [ ] Global market expansion

---

## 📞 Support

### Community
- **Discord**: [Join our community](https://discord.gg/protego-ai)
- **Twitter**: [@ProtegoAI](https://twitter.com/ProtegoAI)
- **Telegram**: [Protego.ai Official](https://t.me/protego_ai)

### Technical Support
- **GitHub Issues**: [Report bugs](https://github.com/protego-ai/sei-contracts/issues)
- **Documentation**: [Full docs](https