// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title NFTTerminal
 * @dev A comprehensive NFT contract for Monad that includes:
 * - Whitelist management with Merkle proofs
 * - Multiple minting phases (whitelist, public)
 * - Token gating verification
 * - Metadata management
 * - Revenue management
 * - Gas-optimized for Monad's high throughput
 */
contract NFTTerminal is 
    ERC721, 
    ERC721URIStorage, 
    ERC721Enumerable, 
    Ownable, 
    Pausable, 
    ReentrancyGuard 
{
    // Events
    event MintPhaseUpdated(MintPhase indexed phase, bool enabled);
    event WhitelistMerkleRootUpdated(bytes32 newRoot);
    event BaseURIUpdated(string newBaseURI);
    event PriceUpdated(uint256 newPrice);
    event MaxSupplyUpdated(uint256 newMaxSupply);
    event TokenGated(address indexed user, uint256 indexed tokenId, string content);
    event RevenueWithdrawn(address indexed to, uint256 amount);

    // Enums
    enum MintPhase {
        CLOSED,
        WHITELIST,
        PUBLIC
    }

    // State variables
    uint256 public constant MAX_BATCH_SIZE = 20; // Optimized for Monad
    uint256 public maxSupply = 10000;
    uint256 public mintPrice = 0.001 ether; // Low price leveraging Monad's low fees
    uint256 private _currentTokenId;
    
    string private _baseTokenURI;
    bytes32 public whitelistMerkleRoot;
    MintPhase public currentPhase = MintPhase.CLOSED;
    
    // Mapping to track whitelist claims
    mapping(address => bool) public whitelistClaimed;
    
    // Mapping for token-gated content
    mapping(uint256 => mapping(string => bool)) public tokenGatedContent;
    
    // Max mints per phase
    uint256 public maxWhitelistMint = 3;
    uint256 public maxPublicMint = 10;
    
    // Track mints per address per phase
    mapping(address => uint256) public whitelistMints;
    mapping(address => uint256) public publicMints;

    constructor(
        string memory name,
        string memory symbol,
        string memory baseURI,
        address initialOwner
    ) ERC721(name, symbol) Ownable(initialOwner) {
        _baseTokenURI = baseURI;
    }

    // Modifiers
    modifier validMintAmount(uint256 amount) {
        require(amount > 0 && amount <= MAX_BATCH_SIZE, "Invalid mint amount");
        require(_currentTokenId + amount <= maxSupply, "Exceeds max supply");
        _;
    }

    modifier correctPayment(uint256 amount) {
        require(msg.value >= mintPrice * amount, "Insufficient payment");
        _;
    }

    // Owner functions
    function setMintPhase(MintPhase phase) external onlyOwner {
        currentPhase = phase;
        emit MintPhaseUpdated(phase, true);
    }

    function setWhitelistMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        whitelistMerkleRoot = _merkleRoot;
        emit WhitelistMerkleRootUpdated(_merkleRoot);
    }

    function setBaseURI(string calldata baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
        emit BaseURIUpdated(baseURI);
    }

    function setMintPrice(uint256 _price) external onlyOwner {
        mintPrice = _price;
        emit PriceUpdated(_price);
    }

    function setMaxSupply(uint256 _maxSupply) external onlyOwner {
        require(_maxSupply >= _currentTokenId, "Max supply cannot be less than current supply");
        maxSupply = _maxSupply;
        emit MaxSupplyUpdated(_maxSupply);
    }

    function setMaxMints(uint256 _maxWhitelist, uint256 _maxPublic) external onlyOwner {
        maxWhitelistMint = _maxWhitelist;
        maxPublicMint = _maxPublic;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // Minting functions
    function whitelistMint(
        uint256 amount,
        bytes32[] calldata merkleProof
    ) 
        external 
        payable 
        nonReentrant 
        whenNotPaused
        validMintAmount(amount)
        correctPayment(amount)
    {
        require(currentPhase == MintPhase.WHITELIST, "Whitelist phase not active");
        require(whitelistMints[msg.sender] + amount <= maxWhitelistMint, "Exceeds whitelist limit");
        
        // Verify merkle proof
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(
            MerkleProof.verify(merkleProof, whitelistMerkleRoot, leaf),
            "Invalid merkle proof"
        );

        whitelistMints[msg.sender] += amount;
        _batchMint(msg.sender, amount);
    }

    function publicMint(uint256 amount) 
        external 
        payable 
        nonReentrant 
        whenNotPaused
        validMintAmount(amount)
        correctPayment(amount)
    {
        require(currentPhase == MintPhase.PUBLIC, "Public phase not active");
        require(publicMints[msg.sender] + amount <= maxPublicMint, "Exceeds public limit");

        publicMints[msg.sender] += amount;
        _batchMint(msg.sender, amount);
    }

    function ownerMint(address to, uint256 amount) 
        external 
        onlyOwner 
        validMintAmount(amount)
    {
        _batchMint(to, amount);
    }

    // Internal minting function optimized for batch operations
    function _batchMint(address to, uint256 amount) internal {
        uint256 startTokenId = _currentTokenId;
        _currentTokenId += amount;

        for (uint256 i = 0; i < amount; i++) {
            _safeMint(to, startTokenId + i);
        }
    }

    // Token gating functions
    function verifyTokenOwnership(address user, uint256 tokenId) external view returns (bool) {
        return ownerOf(tokenId) == user;
    }

    function grantTokenGatedAccess(
        uint256 tokenId, 
        string calldata contentId
    ) external {
        require(ownerOf(tokenId) == msg.sender, "Not token owner");
        tokenGatedContent[tokenId][contentId] = true;
        emit TokenGated(msg.sender, tokenId, contentId);
    }

    function hasTokenGatedAccess(
        uint256 tokenId, 
        string calldata contentId
    ) external view returns (bool) {
        return tokenGatedContent[tokenId][contentId];
    }

    // Batch verification for multiple tokens (gas efficient)
    function verifyMultipleTokenOwnership(
        address user, 
        uint256[] calldata tokenIds
    ) external view returns (bool[] memory) {
        bool[] memory results = new bool[](tokenIds.length);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            results[i] = (ownerOf(tokenIds[i]) == user);
        }
        return results;
    }

    // Revenue management
    function withdrawRevenue() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        
        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdrawal failed");
        
        emit RevenueWithdrawn(owner(), balance);
    }

    function withdrawPartialRevenue(uint256 amount) external onlyOwner nonReentrant {
        require(amount <= address(this).balance, "Insufficient balance");
        
        (bool success, ) = payable(owner()).call{value: amount}("");
        require(success, "Withdrawal failed");
        
        emit RevenueWithdrawn(owner(), amount);
    }

    // View functions
    function tokenURI(uint256 tokenId) 
        public 
        view 
        override(ERC721, ERC721URIStorage) 
        returns (string memory) 
    {
        return super.tokenURI(tokenId);
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function totalSupply() public view override returns (uint256) {
        return _currentTokenId;
    }

    function getUserMintCounts(address user) external view returns (
        uint256 whitelistCount,
        uint256 publicCount
    ) {
        return (whitelistMints[user], publicMints[user]);
    }

    function getContractInfo() external view returns (
        uint256 currentSupply,
        uint256 maxSupplyLimit,
        uint256 price,
        MintPhase phase,
        bool isPaused
    ) {
        return (
            _currentTokenId,
            maxSupply,
            mintPrice,
            currentPhase,
            paused()
        );
    }

    // Required overrides
    function _update(
        address to, 
        uint256 tokenId, 
        address auth
    ) internal override(ERC721, ERC721Enumerable) returns (address) {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(
        address account, 
        uint128 value
    ) internal override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, value);
    }

    function supportsInterface(bytes4 interfaceId) 
        public 
        view 
        override(ERC721, ERC721URIStorage, ERC721Enumerable) 
        returns (bool) 
    {
        return super.supportsInterface(interfaceId);
    }
}
