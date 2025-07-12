# NFT Terminal - No-Code NFT Platform for Monad

NFT Terminal is a comprehensive no-code platform that helps creators, artists, and influencers easily launch and manage NFT collections on Monad. It streamlines the entire process — from minting and whitelisting to analytics and token-gated content — through smart contracts optimized for Monad's high throughput and low fees.

## 🚀 Features

### Core Functionality
- **No-Code NFT Collection Creation**: Deploy NFT collections without coding knowledge
- **Whitelist Management**: Merkle proof-based whitelist system for presales
- **Multiple Minting Phases**: Support for closed, whitelist, and public minting phases
- **Token Gating**: Advanced token-gated access control for exclusive content
- **Revenue Management**: Built-in revenue sharing and withdrawal mechanisms
- **Batch Operations**: Gas-optimized batch minting and verification

### Monad Optimizations
- **Low Fees**: Leverages Monad's low transaction costs
- **High Throughput**: Optimized for Monad's parallel execution capabilities
- **Gas Efficient**: Batch operations and optimized contract architecture
- **Scalable**: Designed to handle high-volume NFT drops

## 📋 Smart Contracts

### 1. NFTTerminal.sol
The core NFT contract with comprehensive functionality:
- **ERC721 Compliant**: Full ERC721 + Extensions support
- **Whitelist Minting**: Merkle proof verification for presales
- **Public Minting**: Open minting with configurable limits
- **Token Gating**: Built-in access control for exclusive content
- **Owner Controls**: Comprehensive admin functions for collection management

### 2. NFTTerminalFactory.sol
Factory contract for deploying NFT collections:
- **No-Code Deployment**: Deploy collections with simple parameters
- **Creator Ownership**: Creators maintain full control of their collections
- **Collection Tracking**: Track all deployed collections and creators
- **Analytics**: Built-in statistics for platform insights

### 3. TokenGatingVerifier.sol
Advanced token gating system for exclusive access:
- **Multi-Collection Rules**: Create rules requiring tokens from multiple collections
- **Content Type Support**: Support for Discord roles, events, exclusive content
- **Batch Verification**: Gas-efficient batch verification of multiple users
- **Flexible Expiry**: Time-based access rules with optional expiration

## 🛠️ Setup and Deployment

### Prerequisites
- [Foundry](https://book.getfoundry.sh/) installed
- Access to Monad Testnet
- Wallet with testnet MON tokens

### Installation
```bash
git clone <repository-url>
cd monadiddy
forge install
```

### Compilation
```bash
forge build
```

### Testing
```bash
# Run all tests
forge test

# Run specific test contract
forge test --match-contract NFTTerminalTest

# Run with verbose output
forge test -vvv
```

### Deployment to Monad Testnet

#### Create Keystore
```bash
cast wallet import monad-deployer --private-key $(cast wallet new | grep 'Private key:' | awk '{print $3}')
```

#### Deploy NFT Terminal System
```bash
# Deploy the complete NFT Terminal system
forge script script/NFTTerminalSystem.s.sol --account monad-deployer --broadcast
```

#### Verify Contracts
```bash
forge verify-contract \
  <contract_address> \
  src/NFTTerminal.sol:NFTTerminal \
  --chain 10143 \
  --verifier sourcify \
  --verifier-url https://sourcify-api-monad.blockvision.org
```

## 🏗️ Architecture

### Core Components

```
┌─────────────────────────────────────────────────────────────┐
│                    NFT Terminal System                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐│
│  │  NFTTerminal    │  │ NFTTerminalFac │  │ TokenGatingVer ││
│  │                 │  │      tory      │  │    ifier       ││
│  │ • ERC721 + Ext  │  │                │  │                ││
│  │ • Minting Logic │  │ • Deploy NFTs  │  │ • Access Rules ││
│  │ • Token Gating  │  │ • Track Colls  │  │ • Multi-Token  ││
│  │ • Revenue Mgmt  │  │ • Analytics    │  │ • Batch Verify ││
│  └─────────────────┘  └─────────────────┘  └─────────────────┘│
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## 🧪 Testing

The project includes comprehensive test suites with 57 passing tests:

### NFTTerminal Tests (23 tests)
- Minting functionality (owner, whitelist, public)
- Token gating and access control
- Revenue management
- Pause/unpause functionality
- Gas efficiency testing

### NFTTerminalFactory Tests (17 tests)
- Collection deployment
- Creator tracking
- Fee management
- Admin controls

### TokenGatingVerifier Tests (17 tests)
- Access rule creation
- Multi-collection verification
- Batch operations
- Expiry handling

## 🔧 Configuration

### Key Parameters

#### NFTTerminal
- `MAX_BATCH_SIZE`: 20 (optimized for Monad)
- `maxSupply`: 10,000 (default)
- `mintPrice`: 0.001 ether (leveraging low Monad fees)
- `maxWhitelistMint`: 3 per address
- `maxPublicMint`: 10 per address

#### Factory
- `collectionCreationFee`: 0.01 ether
- Gas-optimized deployment

#### Verifier
- `ruleCreationFee`: 0.001 ether
- Batch verification support

## 🌟 Monad-Specific Optimizations

### Parallel Execution Ready
- Non-conflicting state updates
- Optimized for concurrent transactions
- Minimal cross-contract dependencies

### Low Fee Structure
- Collection creation: 0.01 MON
- Rule creation: 0.001 MON
- Minting: Starting from 0.001 MON

### High Throughput Design
- Batch operations for multiple tokens
- Efficient gas usage patterns
- Streamlined verification processes

## 🔐 Security Features

- **OpenZeppelin Contracts**: Battle-tested security standards
- **Reentrancy Protection**: ReentrancyGuard on critical functions
- **Access Control**: Comprehensive owner/creator permissions
- **Pausable**: Emergency pause functionality
- **Input Validation**: Extensive parameter validation

## 💰 Gas Costs & Deployment Estimates

### Deployment Costs (Optimized)
- **NFTTerminal**: ~4.79M gas (~23KB bytecode)
- **NFTTerminalFactory**: ~6.81M gas (~31KB bytecode) 
- **TokenGatingVerifier**: ~4.20M gas (~19KB bytecode)
- **Total System**: ~15.80M gas

### Estimated Deployment Costs on Monad
- **Low Gas Price (1 gwei)**: ~0.016 MON
- **Average Gas Price (5 gwei)**: ~0.079 MON  
- **High Gas Price (10 gwei)**: ~0.158 MON

*Costs are significantly lower than Ethereum mainnet due to Monad's optimized fee structure*

### Operation Costs
- **Create Collection**: ~4.7M gas + 0.01 MON fee
- **Mint NFT**: ~100-300K gas depending on batch size
- **Create Access Rule**: ~400K gas + 0.001 MON fee
- **Token Verification**: ~15-80K gas depending on complexity

## 🔧 Troubleshooting

### Common Deployment Issues

#### Contract Size Warnings
```
Error: `Unknown0` is above the contract size limit (31008 > 24576)
```
**Solution**: This warning appears for NFTTerminalFactory but deployment succeeds. The contract is optimized to work within EVM limits.

#### Insufficient Gas
```
Error: Transaction ran out of gas
```
**Solution**: Increase gas limit in deployment script or use `--gas-limit 10000000` flag.

#### RPC Connection Issues
```
Error: Failed to connect to RPC
```
**Solution**: Ensure Monad testnet RPC is accessible:
- Check network status: https://docs.monad.xyz/
- Try alternative RPC endpoints
- Verify wallet has testnet MON tokens

#### Verification Failures
```
Error: Contract verification failed
```
**Solution**: Use Sourcify for verification on Monad:
```bash
forge verify-contract <address> <contract> \
  --chain 10143 \
  --verifier sourcify \
  --verifier-url https://sourcify-api-monad.blockvision.org
```

### Development Tips

#### Local Testing
```bash
# Start Anvil with Monad-like settings
anvil --gas-limit 30000000 --gas-price 1000000000

# Deploy locally first
forge script script/NFTTerminalSystem.s.sol:NFTTerminalSystemScript \
  --rpc-url http://localhost:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast
```

#### Gas Optimization
```bash
# Check gas usage
forge test --gas-report

# Profile specific functions
forge test --match-test test_BatchMint -vvv
```

---

Built with ❤️ for the Monad ecosystem. Leveraging Monad's speed and efficiency to make NFT creation accessible to everyone.