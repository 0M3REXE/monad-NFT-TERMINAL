// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {NFTTerminal} from "./NFTTerminal.sol";

/**
 * @title NFTTerminalFactory
 * @dev Factory contract for deploying NFT Terminal collections
 * Enables no-code NFT collection creation and management
 */
contract NFTTerminalFactory is Ownable, Pausable, ReentrancyGuard {
    // Events
    event CollectionCreated(
        address indexed creator,
        address indexed collection,
        string name,
        string symbol,
        uint256 maxSupply,
        uint256 mintPrice
    );
    event CollectionFeeUpdated(uint256 newFee);
    event FactoryFeeWithdrawn(address indexed to, uint256 amount);

    // State variables
    uint256 public collectionCreationFee = 0.01 ether; // Low fee for Monad
    address[] public deployedCollections;
    
    // Mapping creator to their collections
    mapping(address => address[]) public creatorCollections;
    
    // Mapping collection address to creator
    mapping(address => address) public collectionCreator;
    
    // Collection metadata (simplified for contract size)
    struct CollectionInfo {
        address creator;
        uint256 createdAt;
        bool isActive;
    }
    
    mapping(address => CollectionInfo) public collectionInfo;

    constructor(address initialOwner) Ownable(initialOwner) {}

    /**
     * @dev Create a new NFT collection
     * @param name The name of the NFT collection
     * @param symbol The symbol of the NFT collection
     * @param baseURI The base URI for token metadata
     * @param maxSupply Maximum number of tokens that can be minted
     * @param mintPrice Price per token in wei
     */
    function createCollection(
        string calldata name,
        string calldata symbol,
        string calldata baseURI,
        uint256 maxSupply,
        uint256 mintPrice
    ) external payable whenNotPaused nonReentrant {
        require(msg.value >= collectionCreationFee, "Insufficient creation fee");
        require(bytes(name).length > 0, "Name cannot be empty");
        require(bytes(symbol).length > 0, "Symbol cannot be empty");
        require(maxSupply > 0, "Max supply must be greater than 0");

        // Deploy new NFT Terminal contract
        NFTTerminal newCollection = new NFTTerminal(
            name,
            symbol,
            baseURI,
            msg.sender // Creator becomes the owner
        );

        address collectionAddress = address(newCollection);
        
        // Note: The creator (msg.sender) needs to call setMaxSupply and setMintPrice 
        // themselves after deployment, as the factory cannot call owner functions
        
        // Store collection info (simplified)
        collectionInfo[collectionAddress] = CollectionInfo({
            creator: msg.sender,
            createdAt: block.timestamp,
            isActive: true
        });

        // Track collections
        deployedCollections.push(collectionAddress);
        creatorCollections[msg.sender].push(collectionAddress);
        collectionCreator[collectionAddress] = msg.sender;

        emit CollectionCreated(
            msg.sender,
            collectionAddress,
            name,
            symbol,
            maxSupply,
            mintPrice
        );

        // Refund excess payment
        if (msg.value > collectionCreationFee) {
            (bool success, ) = payable(msg.sender).call{
                value: msg.value - collectionCreationFee
            }("");
            require(success, "Refund failed");
        }
    }

    // View functions
    function getCreatorCollections(address creator) external view returns (address[] memory) {
        return creatorCollections[creator];
    }

    function getAllCollections() external view returns (address[] memory) {
        return deployedCollections;
    }

    function getCollectionCount() external view returns (uint256) {
        return deployedCollections.length;
    }

    function getCreatorCollectionCount(address creator) external view returns (uint256) {
        return creatorCollections[creator].length;
    }

    function getCollectionDetails(address collection) external view returns (
        address creator,
        uint256 createdAt,
        bool isActive
    ) {
        CollectionInfo memory info = collectionInfo[collection];
        return (
            info.creator,
            info.createdAt,
            info.isActive
        );
    }

    function isValidCollection(address collection) external view returns (bool) {
        return collectionInfo[collection].creator != address(0);
    }

    // Admin functions
    function setCollectionCreationFee(uint256 newFee) external onlyOwner {
        collectionCreationFee = newFee;
        emit CollectionFeeUpdated(newFee);
    }

    function withdrawFactoryFees() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");

        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdrawal failed");

        emit FactoryFeeWithdrawn(owner(), balance);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function deactivateCollection(address collection) external onlyOwner {
        require(collectionInfo[collection].creator != address(0), "Invalid collection");
        collectionInfo[collection].isActive = false;
    }

    function reactivateCollection(address collection) external onlyOwner {
        require(collectionInfo[collection].creator != address(0), "Invalid collection");
        collectionInfo[collection].isActive = true;
    }

    // Analytics functions for dashboard
    function getFactoryStats() external view returns (
        uint256 totalCollections,
        uint256 totalCreators,
        uint256 totalFees
    ) {
        return (
            deployedCollections.length,
            0, // Simplified - removed expensive unique creator counting
            address(this).balance
        );
    }
}
