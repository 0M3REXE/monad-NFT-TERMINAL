# NFT Terminal - Web Developer Integration Guide

A comprehensive guide for frontend developers to integrate with the NFT Terminal smart contracts on Monad.

## 🎯 Overview

NFT Terminal provides three main smart contracts for building no-code NFT platforms:
- **NFTTerminalFactory**: Deploy new NFT collections
- **NFTTerminal**: Core NFT functionality (minting, token gating, revenue)
- **TokenGatingVerifier**: Advanced access control across collections

## 🚀 Quick Start

### 1. Contract Addresses (Monad Testnet)

```javascript
const CONTRACTS = {
  FACTORY: "0x...", // NFTTerminalFactory address
  VERIFIER: "0x...", // TokenGatingVerifier address
  // Individual NFT collections deployed via factory
};

const MONAD_TESTNET = {
  chainId: 10143,
  name: "Monad Testnet",
  rpcUrl: "https://sepolia.monad.xyz",
  blockExplorer: "https://sepolia.monad.xyz"
};
```

### 2. Essential Dependencies

```bash
npm install ethers@^6.0.0 @wagmi/core viem
# or
npm install web3@^4.0.0
# or  
npm install @web3-react/core @web3-react/injected-connector
```

### 3. Contract ABIs

```javascript
// Get ABIs from compiled contracts
import FactoryABI from './abis/NFTTerminalFactory.json';
import TerminalABI from './abis/NFTTerminal.json';
import VerifierABI from './abis/TokenGatingVerifier.json';
```

## 🏗️ Core Integration Patterns

### Factory Contract - Deploy New Collections

#### 1. Create a New NFT Collection

```javascript
import { ethers } from 'ethers';

class NFTTerminalFactory {
  constructor(provider, signer, contractAddress) {
    this.contract = new ethers.Contract(contractAddress, FactoryABI, signer);
    this.provider = provider;
  }

  async createCollection({
    name,
    symbol, 
    baseURI,
    maxSupply,
    mintPrice
  }) {
    try {
      // Get creation fee
      const creationFee = await this.contract.collectionCreationFee();
      
      // Create collection
      const tx = await this.contract.createCollection(
        name,
        symbol,
        baseURI,
        maxSupply,
        ethers.parseEther(mintPrice.toString()),
        {
          value: creationFee,
          gasLimit: 5000000 // Adjust based on needs
        }
      );

      const receipt = await tx.wait();
      
      // Extract new collection address from events
      const event = receipt.logs.find(log => 
        log.topics[0] === ethers.id("CollectionCreated(address,address,string,string,uint256,uint256)")
      );
      
      if (event) {
        const decoded = this.contract.interface.parseLog(event);
        return {
          success: true,
          collectionAddress: decoded.args.collection,
          creator: decoded.args.creator,
          txHash: receipt.hash
        };
      }
      
      throw new Error("Collection creation event not found");
    } catch (error) {
      return {
        success: false,
        error: error.message
      };
    }
  }

  async getCreatorCollections(creatorAddress) {
    return await this.contract.getCreatorCollections(creatorAddress);
  }

  async getFactoryStats() {
    const [totalCollections, totalCreators, totalFees] = 
      await this.contract.getFactoryStats();
    
    return {
      totalCollections: Number(totalCollections),
      totalCreators: Number(totalCreators), 
      totalFees: ethers.formatEther(totalFees)
    };
  }
}
```

#### 2. Frontend Component Example (React)

```jsx
import React, { useState } from 'react';
import { useAccount, useContractWrite, usePrepareContractWrite } from 'wagmi';

function CreateCollectionForm() {
  const { address } = useAccount();
  const [formData, setFormData] = useState({
    name: '',
    symbol: '',
    baseURI: '',
    maxSupply: 10000,
    mintPrice: '0.001'
  });

  const { config } = usePrepareContractWrite({
    address: CONTRACTS.FACTORY,
    abi: FactoryABI,
    functionName: 'createCollection',
    args: [
      formData.name,
      formData.symbol, 
      formData.baseURI,
      formData.maxSupply,
      ethers.parseEther(formData.mintPrice)
    ],
    value: ethers.parseEther('0.01'), // Creation fee
  });

  const { write, isLoading } = useContractWrite(config);

  const handleSubmit = (e) => {
    e.preventDefault();
    write?.();
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div>
        <label>Collection Name</label>
        <input
          type="text"
          value={formData.name}
          onChange={(e) => setFormData({...formData, name: e.target.value})}
          className="w-full p-2 border rounded"
          required
        />
      </div>
      
      <div>
        <label>Symbol</label>
        <input
          type="text"
          value={formData.symbol}
          onChange={(e) => setFormData({...formData, symbol: e.target.value})}
          className="w-full p-2 border rounded"
          required
        />
      </div>

      <div>
        <label>Base URI (IPFS)</label>
        <input
          type="url"
          value={formData.baseURI}
          onChange={(e) => setFormData({...formData, baseURI: e.target.value})}
          placeholder="https://gateway.pinata.cloud/ipfs/..."
          className="w-full p-2 border rounded"
          required
        />
      </div>

      <div>
        <label>Max Supply</label>
        <input
          type="number"
          value={formData.maxSupply}
          onChange={(e) => setFormData({...formData, maxSupply: parseInt(e.target.value)})}
          className="w-full p-2 border rounded"
          required
        />
      </div>

      <div>
        <label>Mint Price (MON)</label>
        <input
          type="number"
          step="0.001"
          value={formData.mintPrice}
          onChange={(e) => setFormData({...formData, mintPrice: e.target.value})}
          className="w-full p-2 border rounded"
          required
        />
      </div>

      <button 
        type="submit"
        disabled={!write || isLoading}
        className="w-full bg-blue-500 text-white p-2 rounded disabled:bg-gray-300"
      >
        {isLoading ? 'Creating...' : 'Create Collection'}
      </button>
    </form>
  );
}
```

### NFT Terminal - Collection Management

#### 1. Minting Interface

```javascript
class NFTTerminal {
  constructor(contractAddress, provider, signer) {
    this.contract = new ethers.Contract(contractAddress, TerminalABI, signer);
    this.provider = provider;
  }

  async getCollectionInfo() {
    const [name, symbol, totalSupply, maxSupply, mintPrice, currentPhase] = 
      await Promise.all([
        this.contract.name(),
        this.contract.symbol(),
        this.contract.totalSupply(),
        this.contract.maxSupply(),
        this.contract.mintPrice(),
        this.contract.currentPhase()
      ]);

    return {
      name,
      symbol,
      totalSupply: Number(totalSupply),
      maxSupply: Number(maxSupply),
      mintPrice: ethers.formatEther(mintPrice),
      currentPhase: Number(currentPhase), // 0=CLOSED, 1=WHITELIST, 2=PUBLIC
      phases: ['CLOSED', 'WHITELIST', 'PUBLIC']
    };
  }

  async publicMint(quantity, userAddress) {
    try {
      const mintPrice = await this.contract.mintPrice();
      const totalCost = mintPrice * BigInt(quantity);
      
      const tx = await this.contract.publicMint(quantity, {
        value: totalCost,
        gasLimit: 200000 * quantity // Estimate gas per mint
      });

      return {
        success: true,
        txHash: tx.hash,
        receipt: await tx.wait()
      };
    } catch (error) {
      return {
        success: false,
        error: this.parseError(error)
      };
    }
  }

  async ownerMint(to, quantity) {
    // Only collection owner can call this
    const tx = await this.contract.ownerMint(to, quantity);
    return await tx.wait();
  }

  async whitelistMint(quantity, merkleProof) {
    const mintPrice = await this.contract.mintPrice();
    const totalCost = mintPrice * BigInt(quantity);
    
    const tx = await this.contract.whitelistMint(quantity, merkleProof, {
      value: totalCost
    });
    return await tx.wait();
  }

  parseError(error) {
    // Parse common errors for better UX
    if (error.message.includes('ExceedsMaxSupply')) {
      return 'Not enough tokens available for minting';
    }
    if (error.message.includes('InsufficientPayment')) {
      return 'Insufficient payment for minting';
    }
    if (error.message.includes('ExceedsUserLimit')) {
      return 'Exceeds maximum mints per user';
    }
    return error.message;
  }
}
```

#### 2. Minting Component (React)

```jsx
function MintingInterface({ collectionAddress }) {
  const [quantity, setQuantity] = useState(1);
  const [collectionInfo, setCollectionInfo] = useState(null);
  const [minting, setMinting] = useState(false);
  const { address } = useAccount();

  useEffect(() => {
    loadCollectionInfo();
  }, [collectionAddress]);

  const loadCollectionInfo = async () => {
    const terminal = new NFTTerminal(collectionAddress, provider, signer);
    const info = await terminal.getCollectionInfo();
    setCollectionInfo(info);
  };

  const handleMint = async () => {
    setMinting(true);
    try {
      const terminal = new NFTTerminal(collectionAddress, provider, signer);
      const result = await terminal.publicMint(quantity, address);
      
      if (result.success) {
        toast.success(`Successfully minted ${quantity} NFTs!`);
        loadCollectionInfo(); // Refresh data
      } else {
        toast.error(result.error);
      }
    } catch (error) {
      toast.error('Minting failed');
    } finally {
      setMinting(false);
    }
  };

  if (!collectionInfo) return <div>Loading...</div>;

  const canMint = collectionInfo.currentPhase === 2; // PUBLIC phase
  const totalCost = parseFloat(collectionInfo.mintPrice) * quantity;

  return (
    <div className="bg-white p-6 rounded-lg shadow">
      <h2 className="text-2xl font-bold mb-4">{collectionInfo.name}</h2>
      
      <div className="mb-4">
        <p>Supply: {collectionInfo.totalSupply} / {collectionInfo.maxSupply}</p>
        <p>Price: {collectionInfo.mintPrice} MON</p>
        <p>Phase: {collectionInfo.phases[collectionInfo.currentPhase]}</p>
      </div>

      {canMint ? (
        <div>
          <div className="mb-4">
            <label className="block mb-2">Quantity:</label>
            <input
              type="number"
              min="1"
              max="10"
              value={quantity}
              onChange={(e) => setQuantity(parseInt(e.target.value))}
              className="w-20 p-2 border rounded"
            />
          </div>
          
          <div className="mb-4">
            <p className="text-lg font-semibold">
              Total: {totalCost.toFixed(3)} MON
            </p>
          </div>

          <button
            onClick={handleMint}
            disabled={minting || !address}
            className="bg-blue-500 text-white px-6 py-2 rounded disabled:bg-gray-300"
          >
            {minting ? 'Minting...' : `Mint ${quantity} NFT${quantity > 1 ? 's' : ''}`}
          </button>
        </div>
      ) : (
        <p className="text-red-500">Minting is not currently active</p>
      )}
    </div>
  );
}
```

### Token Gating - Access Control

#### 1. Access Rule Creation

```javascript
class TokenGatingVerifier {
  constructor(contractAddress, provider, signer) {
    this.contract = new ethers.Contract(contractAddress, VerifierABI, signer);
  }

  async createAccessRule({
    contentType, // "discord", "event", "content", "utility"
    description,
    requiredCollections, // Array of NFT contract addresses
    minimumTokensPerCollection, // Array of minimum token counts
    expiryTime = 0 // 0 for no expiry
  }) {
    try {
      const ruleCreationFee = await this.contract.ruleCreationFee();
      
      const tx = await this.contract.createAccessRule(
        contentType,
        description,
        requiredCollections,
        minimumTokensPerCollection,
        expiryTime,
        {
          value: ruleCreationFee
        }
      );

      const receipt = await tx.wait();
      
      // Extract rule ID from events
      const event = receipt.logs.find(log => 
        log.topics[0] === ethers.id("AccessRuleCreated(bytes32,address,string,address[],uint256[])")
      );
      
      if (event) {
        const decoded = this.contract.interface.parseLog(event);
        return {
          success: true,
          ruleId: decoded.args.ruleId,
          txHash: receipt.hash
        };
      }
      
      throw new Error("Rule creation event not found");
    } catch (error) {
      return {
        success: false,
        error: error.message
      };
    }
  }

  async verifyAccess(ruleId, userAddress) {
    const [hasAccess, details] = await this.contract.verifyAccess(ruleId, userAddress);
    return { hasAccess, details };
  }

  async batchVerifyAccess(ruleId, userAddresses) {
    const results = await this.contract.batchVerifyAccess(ruleId, userAddresses);
    return userAddresses.map((address, i) => ({
      address,
      hasAccess: results[i]
    }));
  }

  async getAccessRule(ruleId) {
    const [
      contentType,
      description,
      requiredCollections,
      minimumTokensPerCollection,
      creator,
      isActive,
      createdAt,
      expiryTime
    ] = await this.contract.getAccessRule(ruleId);

    return {
      contentType,
      description,
      requiredCollections,
      minimumTokensPerCollection: minimumTokensPerCollection.map(n => Number(n)),
      creator,
      isActive,
      createdAt: Number(createdAt),
      expiryTime: Number(expiryTime)
    };
  }
}
```

#### 2. Discord Bot Integration Example

```javascript
// Example Discord bot integration
class DiscordTokenGating {
  constructor(verifierAddress, provider) {
    this.verifier = new TokenGatingVerifier(verifierAddress, provider, null);
  }

  async verifyUserForRole(userId, walletAddress, ruleId) {
    try {
      const result = await this.verifier.verifyAccess(ruleId, walletAddress);
      
      if (result.hasAccess) {
        // Grant Discord role
        await this.grantDiscordRole(userId, ruleId);
        return { success: true, message: "Role granted!" };
      } else {
        return { success: false, message: result.details };
      }
    } catch (error) {
      return { success: false, message: "Verification failed" };
    }
  }

  async grantDiscordRole(userId, ruleId) {
    // Implement Discord API call to grant role
    // This would use Discord.js or similar
  }

  // Webhook endpoint for Discord verification
  async handleDiscordCommand(interaction) {
    const walletAddress = interaction.options.getString('wallet');
    const ruleId = process.env.DISCORD_RULE_ID;
    
    const result = await this.verifyUserForRole(
      interaction.user.id,
      walletAddress,
      ruleId
    );
    
    await interaction.reply(result.message);
  }
}
```

## 🎨 Frontend Patterns & Best Practices

### 1. State Management (Redux/Zustand)

```javascript
// Store example using Zustand
import { create } from 'zustand';

const useNFTStore = create((set, get) => ({
  // State
  collections: [],
  selectedCollection: null,
  userTokens: [],
  loading: false,
  
  // Actions
  setLoading: (loading) => set({ loading }),
  
  setCollections: (collections) => set({ collections }),
  
  selectCollection: (collectionAddress) => {
    const collection = get().collections.find(c => c.address === collectionAddress);
    set({ selectedCollection: collection });
  },
  
  addUserToken: (token) => set((state) => ({
    userTokens: [...state.userTokens, token]
  })),
  
  // Async actions
  loadUserCollections: async (userAddress, factoryContract) => {
    set({ loading: true });
    try {
      const collections = await factoryContract.getCreatorCollections(userAddress);
      set({ collections, loading: false });
    } catch (error) {
      set({ loading: false });
      throw error;
    }
  }
}));
```

### 2. Error Handling

```javascript
// Centralized error handling
class ContractErrorHandler {
  static parseContractError(error) {
    const errorMap = {
      'InsufficientPayment': 'Payment amount is too low',
      'ExceedsMaxSupply': 'Not enough tokens available',
      'ExceedsUserLimit': 'You have reached the maximum mint limit',
      'InvalidMintPhase': 'Minting is not currently active',
      'InvalidProof': 'You are not on the whitelist',
      'user rejected transaction': 'Transaction was cancelled',
      'insufficient funds': 'Insufficient funds in wallet'
    };

    for (const [key, message] of Object.entries(errorMap)) {
      if (error.message.includes(key)) {
        return message;
      }
    }

    return 'Transaction failed. Please try again.';
  }

  static async handleAsyncOperation(operation, errorCallback) {
    try {
      return await operation();
    } catch (error) {
      const userMessage = this.parseContractError(error);
      errorCallback?.(userMessage);
      throw new Error(userMessage);
    }
  }
}
```

### 3. Real-time Updates with Events

```javascript
// Event listener setup
class ContractEventListener {
  constructor(contract, provider) {
    this.contract = contract;
    this.provider = provider;
    this.listeners = new Map();
  }

  startListening() {
    // Listen for new collections
    this.contract.on('CollectionCreated', (creator, collection, name, symbol, maxSupply, mintPrice, event) => {
      this.emit('newCollection', {
        creator,
        collection,
        name,
        symbol,
        maxSupply: Number(maxSupply),
        mintPrice: ethers.formatEther(mintPrice),
        blockNumber: event.blockNumber
      });
    });

    // Listen for mints
    this.contract.on('Transfer', (from, to, tokenId, event) => {
      if (from === ethers.ZeroAddress) { // Mint event
        this.emit('tokenMinted', {
          to,
          tokenId: Number(tokenId),
          blockNumber: event.blockNumber
        });
      }
    });
  }

  on(eventName, callback) {
    if (!this.listeners.has(eventName)) {
      this.listeners.set(eventName, []);
    }
    this.listeners.get(eventName).push(callback);
  }

  emit(eventName, data) {
    const callbacks = this.listeners.get(eventName) || [];
    callbacks.forEach(callback => callback(data));
  }

  stopListening() {
    this.contract.removeAllListeners();
  }
}
```

### 4. IPFS Integration

```javascript
// IPFS metadata handling
class IPFSManager {
  constructor(pinataApiKey, pinataSecretKey) {
    this.pinataApiKey = pinataApiKey;
    this.pinataSecretKey = pinataSecretKey;
  }

  async uploadMetadata(metadata) {
    const url = 'https://api.pinata.cloud/pinning/pinJSONToIPFS';
    
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'pinata_api_key': this.pinataApiKey,
        'pinata_secret_api_key': this.pinataSecretKey
      },
      body: JSON.stringify(metadata)
    });

    const result = await response.json();
    return `https://gateway.pinata.cloud/ipfs/${result.IpfsHash}`;
  }

  async uploadImage(file) {
    const formData = new FormData();
    formData.append('file', file);

    const response = await fetch('https://api.pinata.cloud/pinning/pinFileToIPFS', {
      method: 'POST',
      headers: {
        'pinata_api_key': this.pinataApiKey,
        'pinata_secret_api_key': this.pinataSecretKey
      },
      body: formData
    });

    const result = await response.json();
    return `https://gateway.pinata.cloud/ipfs/${result.IpfsHash}`;
  }

  // Generate metadata for NFT
  generateMetadata(name, description, imageUrl, attributes = []) {
    return {
      name,
      description,
      image: imageUrl,
      attributes,
      external_url: "https://your-platform.com",
      background_color: "ffffff"
    };
  }
}
```

## 🔒 Security Best Practices

### 1. Input Validation

```javascript
// Validate addresses
function isValidAddress(address) {
  return ethers.isAddress(address);
}

// Validate amounts
function validateMintAmount(amount, maxPerTx = 20) {
  const num = parseInt(amount);
  return num > 0 && num <= maxPerTx;
}

// Sanitize inputs
function sanitizeInput(input) {
  return input.trim().replace(/[<>]/g, '');
}
```

### 2. Rate Limiting

```javascript
// Simple rate limiting for API calls
class RateLimiter {
  constructor(maxCalls = 10, windowMs = 60000) {
    this.calls = new Map();
    this.maxCalls = maxCalls;
    this.windowMs = windowMs;
  }

  canMakeCall(identifier) {
    const now = Date.now();
    const userCalls = this.calls.get(identifier) || [];
    
    // Remove calls outside the window
    const validCalls = userCalls.filter(time => now - time < this.windowMs);
    
    if (validCalls.length >= this.maxCalls) {
      return false;
    }
    
    validCalls.push(now);
    this.calls.set(identifier, validCalls);
    return true;
  }
}
```

### 3. Secure Transaction Handling

```javascript
// Safe transaction execution
async function executeTransaction(contractMethod, options = {}) {
  try {
    // Estimate gas first
    const gasEstimate = await contractMethod.estimateGas(options);
    const gasLimit = gasEstimate * 120n / 100n; // 20% buffer
    
    // Execute with proper gas limit
    const tx = await contractMethod({
      ...options,
      gasLimit
    });
    
    // Wait for confirmation
    const receipt = await tx.wait(2); // Wait for 2 confirmations
    
    return {
      success: true,
      receipt,
      txHash: receipt.hash
    };
  } catch (error) {
    return {
      success: false,
      error: ContractErrorHandler.parseContractError(error)
    };
  }
}
```

## 📱 Mobile Considerations

### 1. Wallet Connect Integration

```javascript
import { WalletConnect } from '@walletconnect/web3-provider';

class MobileWalletProvider {
  constructor() {
    this.provider = null;
  }

  async connect() {
    const provider = new WalletConnect({
      infuraId: "your-infura-id", 
      rpc: {
        10143: "https://sepolia.monad.xyz"
      },
      chainId: 10143,
      qrcode: true,
      qrcodeModalOptions: {
        mobileLinks: [
          "metamask",
          "trust",
          "rainbow",
          "argent",
          "imtoken",
          "pillar"
        ]
      }
    });

    await provider.enable();
    this.provider = provider;
    return provider;
  }
}
```

### 2. Responsive Design Patterns

```jsx
// Mobile-first minting interface
function MobileMintInterface() {
  const [isOpen, setIsOpen] = useState(false);
  
  return (
    <div className="fixed bottom-0 left-0 right-0 bg-white border-t lg:relative lg:border-0">
      <div className="p-4">
        <button
          onClick={() => setIsOpen(!isOpen)}
          className="w-full bg-blue-500 text-white p-3 rounded-lg text-lg font-semibold lg:hidden"
        >
          Mint NFT
        </button>
        
        <div className={`${isOpen ? 'block' : 'hidden'} lg:block mt-4 lg:mt-0`}>
          {/* Minting interface */}
        </div>
      </div>
    </div>
  );
}
```

## 🚀 Deployment & Environment Setup

### 1. Environment Configuration

```javascript
// config.js
const config = {
  development: {
    chainId: 31337,
    rpcUrl: "http://localhost:8545",
    contracts: {
      factory: "0x...",
      verifier: "0x..."
    }
  },
  testnet: {
    chainId: 10143,
    rpcUrl: "https://sepolia.monad.xyz",
    contracts: {
      factory: "0x...",
      verifier: "0x..."
    }
  },
  mainnet: {
    chainId: 1, // Monad mainnet when available
    rpcUrl: "https://mainnet.monad.xyz",
    contracts: {
      factory: "0x...",
      verifier: "0x..."
    }
  }
};

export default config[process.env.NODE_ENV || 'development'];
```

### 2. Testing Strategy

```javascript
// Integration tests
describe('NFT Terminal Integration', () => {
  test('Complete minting flow', async () => {
    // 1. Create collection
    const factory = new NFTTerminalFactory(provider, signer, FACTORY_ADDRESS);
    const createResult = await factory.createCollection({
      name: "Test Collection",
      symbol: "TEST",
      baseURI: "https://test.com/",
      maxSupply: 1000,
      mintPrice: "0.001"
    });
    
    expect(createResult.success).toBe(true);
    
    // 2. Set up collection for minting
    const terminal = new NFTTerminal(createResult.collectionAddress, provider, signer);
    await terminal.contract.setMintPhase(2); // PUBLIC
    
    // 3. Mint tokens
    const mintResult = await terminal.publicMint(1, userAddress);
    expect(mintResult.success).toBe(true);
  });
});
```

## 📚 Additional Resources

### Documentation Links
- [Ethers.js Documentation](https://docs.ethers.org/)
- [Wagmi Documentation](https://wagmi.sh/)
- [IPFS Documentation](https://docs.ipfs.io/)
- [Monad Documentation](https://docs.monad.xyz/)

### Example Projects
- [Complete React Integration](./examples/react-integration/)
- [Discord Bot Example](./examples/discord-bot/)
- [Mobile App Example](./examples/mobile-app/)

### Support
- [GitHub Issues](https://github.com/your-repo/issues)
- [Discord Community](https://discord.gg/your-community)
- [Documentation Site](https://docs.your-platform.com)

---

**Built for Monad's high-performance blockchain. Leveraging speed, low fees, and parallel execution for the next generation of NFT platforms.**
