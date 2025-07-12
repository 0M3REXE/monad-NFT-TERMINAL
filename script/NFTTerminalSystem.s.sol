// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {NFTTerminal} from "../src/NFTTerminal.sol";
import {NFTTerminalFactory} from "../src/NFTTerminalFactory.sol";
import {TokenGatingVerifier} from "../src/TokenGatingVerifier.sol";

contract NFTTerminalSystemScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        
        address deployer = msg.sender;
        console.log("Deploying NFT Terminal System...");
        console.log("Deployer:", deployer);
        console.log("Note: Monad supports up to 128KB contract size vs Ethereum's 24KB limit");
        
        // Deploy Factory Contract
        NFTTerminalFactory factory = new NFTTerminalFactory(deployer);
        console.log("NFT Terminal Factory deployed to:", address(factory));
        
        // Deploy Token Gating Verifier
        TokenGatingVerifier verifier = new TokenGatingVerifier(deployer);
        console.log("Token Gating Verifier deployed to:", address(verifier));
        
        // Deploy a sample NFT Terminal for demonstration
        NFTTerminal sampleNFT = new NFTTerminal(
            "Monad Sample Collection",
            "MONAD",
            "https://api.monadnft.com/metadata/",
            deployer
        );
        console.log("Sample NFT Terminal deployed to:", address(sampleNFT));
        
        // Configure the sample NFT (deployer is owner)
        sampleNFT.setMaxSupply(1000);
        sampleNFT.setMintPrice(0.001 ether); // Low price for Monad
        sampleNFT.setMintPhase(NFTTerminal.MintPhase.PUBLIC);
        
        console.log("Sample NFT configured:");
        console.log("  Max Supply:", sampleNFT.maxSupply());
        console.log("  Mint Price:", sampleNFT.mintPrice());
        console.log("  Current Phase:", uint256(sampleNFT.currentPhase()));
        
        console.log("\n=== NFT Terminal System Deployment Summary ===");
        console.log("Factory Address:", address(factory));
        console.log("Verifier Address:", address(verifier));
        console.log("Sample NFT Address:", address(sampleNFT));
        console.log("Factory Fee:", factory.collectionCreationFee());
        console.log("Verifier Fee:", verifier.ruleCreationFee());
        
        console.log("\n=== Next Steps ===");
        console.log("1. Creators can use the factory to deploy NFT collections");
        console.log("2. Use the verifier to create token-gated experiences");
        console.log("3. Integrate with frontend for no-code platform");
        
        vm.stopBroadcast();
    }
}
