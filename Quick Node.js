const { ethers } = require('ethers');

// Your deployed contract addresses
const CONTRACTS = {
    FACTORY: "0x5FbDB2315678afecb367f032d93F642f64180aa3",
    SAMPLE_NFT: "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0"
};

const FACTORY_ABI = [
    "function createCollection(string,string,string,uint256,uint256) external payable returns (address)",
    "function getCollectionCount() external view returns (uint256)",
    "function collectionCreationFee() external view returns (uint256)"
];

const TERMINAL_ABI = [
    "function name() external view returns (string)",
    "function totalSupply() external view returns (uint256)",
    "function mintPrice() external view returns (uint256)",
    "function currentPhase() external view returns (uint8)",
    "function publicMint(uint256) external payable",
    "function balanceOf(address) external view returns (uint256)"
];

async function quickTest() {
    console.log("🚀 Quick NFT Terminal Test\n");
    
    // Connect to Anvil
    const provider = new ethers.JsonRpcProvider("http://localhost:8545");
    const signer = new ethers.Wallet("0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80", provider);
    
    console.log(`👤 Using account: ${signer.address}\n`);
    
    // Test Factory
    const factory = new ethers.Contract(CONTRACTS.FACTORY, FACTORY_ABI, signer);
    
    console.log("📋 Factory Info:");
    const collectionCount = await factory.getCollectionCount();
    const creationFee = await factory.collectionCreationFee();
    console.log(`• Collections: ${collectionCount.toString()}`);
    console.log(`• Creation Fee: ${ethers.formatEther(creationFee)} ETH\n`);
    
    // Create new collection
    console.log("🎨 Creating new collection...");
    const createTx = await factory.createCollection(
        "Quick Test NFTs",
        "QTN",
        "https://api.test.com/metadata/",
        100,
        ethers.parseEther("0.01"),
        { value: creationFee }
    );
    
    const createReceipt = await createTx.wait();
    console.log(`✅ Collection created! TX: ${createReceipt.hash}\n`);
    
    // Test sample NFT minting
    console.log("💎 Testing Sample NFT Minting:");
    const sampleNFT = new ethers.Contract(CONTRACTS.SAMPLE_NFT, TERMINAL_ABI, signer);
    
    const name = await sampleNFT.name();
    const supply = await sampleNFT.totalSupply();
    const price = await sampleNFT.mintPrice();
    const phase = await sampleNFT.currentPhase();
    
    console.log(`• Collection: ${name}`);
    console.log(`• Supply: ${supply.toString()}`);
    console.log(`• Price: ${ethers.formatEther(price)} ETH`);
    console.log(`• Phase: ${phase} (2 = PUBLIC)\n`);
    
    if (phase === 2n) { // PUBLIC phase
        console.log("🎯 Minting 2 NFTs...");
        const mintTx = await sampleNFT.publicMint(2, {
            value: price * 2n
        });
        
        const mintReceipt = await mintTx.wait();
        console.log(`✅ Minted successfully! TX: ${mintReceipt.hash}`);
        
        const balance = await sampleNFT.balanceOf(signer.address);
        console.log(`🏆 Your NFT balance: ${balance.toString()}\n`);
    }
    
    console.log("🎉 Test completed successfully!");
}

quickTest().catch(console.error);