// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title TokenGatingVerifier
 * @dev Manages token-gated access across multiple NFT collections
 * Provides verification for exclusive content, Discord roles, events, etc.
 */
contract TokenGatingVerifier is Ownable, Pausable {
    // Events
    event AccessRuleCreated(
        bytes32 indexed ruleId,
        address indexed creator,
        string contentType,
        address[] collections,
        uint256[] minimumTokens
    );
    event AccessGranted(
        bytes32 indexed ruleId,
        address indexed user,
        string contentType
    );
    event AccessRevoked(
        bytes32 indexed ruleId,
        address indexed user,
        string contentType
    );
    event RuleUpdated(bytes32 indexed ruleId, bool isActive);

    // Structs
    struct AccessRule {
        string contentType; // "discord", "event", "content", "utility"
        string description;
        address[] requiredCollections;
        uint256[] minimumTokensPerCollection;
        address creator;
        bool isActive;
        uint256 createdAt;
        uint256 expiryTime; // 0 for no expiry
    }

    struct UserAccess {
        bool hasAccess;
        uint256 grantedAt;
        uint256 lastVerified;
    }

    // State variables
    mapping(bytes32 => AccessRule) public accessRules;
    mapping(bytes32 => mapping(address => UserAccess)) public userAccess;
    mapping(address => bytes32[]) public creatorRules;
    
    bytes32[] public allRules;
    
    // Access tracking
    mapping(address => mapping(string => bool)) public globalAccess;
    
    // Fee for creating access rules (leveraging Monad's low fees)
    uint256 public ruleCreationFee = 0.001 ether;

    constructor(address initialOwner) Ownable(initialOwner) {}

    /**
     * @dev Create a new token gating rule
     * @param contentType Type of content being gated
     * @param description Human readable description
     * @param requiredCollections Array of NFT collection addresses
     * @param minimumTokensPerCollection Minimum tokens required from each collection
     * @param expiryTime Expiry timestamp (0 for no expiry)
     */
    function createAccessRule(
        string calldata contentType,
        string calldata description,
        address[] calldata requiredCollections,
        uint256[] calldata minimumTokensPerCollection,
        uint256 expiryTime
    ) external payable whenNotPaused returns (bytes32 ruleId) {
        require(msg.value >= ruleCreationFee, "Insufficient fee");
        require(bytes(contentType).length > 0, "Content type required");
        require(requiredCollections.length > 0, "At least one collection required");
        require(
            requiredCollections.length == minimumTokensPerCollection.length,
            "Array length mismatch"
        );

        // Verify all addresses are valid ERC721 contracts
        for (uint256 i = 0; i < requiredCollections.length; i++) {
            require(requiredCollections[i] != address(0), "Invalid collection address");
            require(minimumTokensPerCollection[i] > 0, "Minimum tokens must be > 0");
            
            // Check if contract supports ERC721
            try IERC165(requiredCollections[i]).supportsInterface(0x80ac58cd) returns (bool supported) {
                require(supported, "Contract must support ERC721");
            } catch {
                revert("Invalid ERC721 contract");
            }
        }

        // Generate unique rule ID
        ruleId = keccak256(abi.encodePacked(
            msg.sender,
            contentType,
            block.timestamp,
            block.prevrandao
        ));

        // Store access rule
        accessRules[ruleId] = AccessRule({
            contentType: contentType,
            description: description,
            requiredCollections: requiredCollections,
            minimumTokensPerCollection: minimumTokensPerCollection,
            creator: msg.sender,
            isActive: true,
            createdAt: block.timestamp,
            expiryTime: expiryTime
        });

        allRules.push(ruleId);
        creatorRules[msg.sender].push(ruleId);

        emit AccessRuleCreated(
            ruleId,
            msg.sender,
            contentType,
            requiredCollections,
            minimumTokensPerCollection
        );

        // Refund excess payment
        if (msg.value > ruleCreationFee) {
            (bool success, ) = payable(msg.sender).call{
                value: msg.value - ruleCreationFee
            }("");
            require(success, "Refund failed");
        }

        return ruleId;
    }

    /**
     * @dev Verify if a user meets the requirements for a specific rule
     * @param ruleId The access rule to verify against
     * @param user The user address to verify
     * @return hasAccess Whether the user has access
     * @return details Additional verification details
     */
    function verifyAccess(bytes32 ruleId, address user) 
        external 
        view 
        returns (bool hasAccess, string memory details) 
    {
        AccessRule memory rule = accessRules[ruleId];
        
        if (!rule.isActive) {
            return (false, "Rule is not active");
        }
        
        if (rule.expiryTime > 0 && block.timestamp > rule.expiryTime) {
            return (false, "Rule has expired");
        }

        // Check each required collection
        for (uint256 i = 0; i < rule.requiredCollections.length; i++) {
            IERC721 collection = IERC721(rule.requiredCollections[i]);
            uint256 userBalance = collection.balanceOf(user);
            
            if (userBalance < rule.minimumTokensPerCollection[i]) {
                return (false, string(abi.encodePacked(
                    "Insufficient tokens in collection ",
                    _addressToString(rule.requiredCollections[i])
                )));
            }
        }

        return (true, "Access granted");
    }

    /**
     * @dev Grant access to a user for a specific rule (to be called after verification)
     * @param ruleId The access rule
     * @param user The user to grant access to
     */
    function grantAccess(bytes32 ruleId, address user) external {
        AccessRule memory rule = accessRules[ruleId];
        require(rule.creator == msg.sender, "Only rule creator can grant access");
        
        (bool hasAccess, ) = this.verifyAccess(ruleId, user);
        require(hasAccess, "User does not meet requirements");

        userAccess[ruleId][user] = UserAccess({
            hasAccess: true,
            grantedAt: block.timestamp,
            lastVerified: block.timestamp
        });

        globalAccess[user][rule.contentType] = true;

        emit AccessGranted(ruleId, user, rule.contentType);
    }

    /**
     * @dev Revoke access for a user
     * @param ruleId The access rule
     * @param user The user to revoke access from
     */
    function revokeAccess(bytes32 ruleId, address user) external {
        AccessRule memory rule = accessRules[ruleId];
        require(
            rule.creator == msg.sender || msg.sender == owner(),
            "Unauthorized to revoke access"
        );

        userAccess[ruleId][user].hasAccess = false;
        globalAccess[user][rule.contentType] = false;

        emit AccessRevoked(ruleId, user, rule.contentType);
    }

    /**
     * @dev Batch verify multiple users for a rule (gas efficient)
     * @param ruleId The access rule to verify against
     * @param users Array of user addresses
     * @return results Array of verification results
     */
    function batchVerifyAccess(bytes32 ruleId, address[] calldata users)
        external
        view
        returns (bool[] memory results)
    {
        results = new bool[](users.length);
        
        for (uint256 i = 0; i < users.length; i++) {
            (bool hasAccess, ) = this.verifyAccess(ruleId, users[i]);
            results[i] = hasAccess;
        }
        
        return results;
    }

    /**
     * @dev Check if user has access to any content of a specific type
     * @param user The user address
     * @param contentType The content type to check
     * @return hasAccess Whether user has access to this content type
     */
    function hasContentTypeAccess(address user, string calldata contentType)
        external
        view
        returns (bool hasAccess)
    {
        return globalAccess[user][contentType];
    }

    // View functions
    function getAccessRule(bytes32 ruleId) external view returns (
        string memory contentType,
        string memory description,
        address[] memory requiredCollections,
        uint256[] memory minimumTokensPerCollection,
        address creator,
        bool isActive,
        uint256 createdAt,
        uint256 expiryTime
    ) {
        AccessRule memory rule = accessRules[ruleId];
        return (
            rule.contentType,
            rule.description,
            rule.requiredCollections,
            rule.minimumTokensPerCollection,
            rule.creator,
            rule.isActive,
            rule.createdAt,
            rule.expiryTime
        );
    }

    function getCreatorRules(address creator) external view returns (bytes32[] memory) {
        return creatorRules[creator];
    }

    function getAllRules() external view returns (bytes32[] memory) {
        return allRules;
    }

    function getUserAccessInfo(bytes32 ruleId, address user) external view returns (
        bool hasAccess,
        uint256 grantedAt,
        uint256 lastVerified
    ) {
        UserAccess memory access = userAccess[ruleId][user];
        return (access.hasAccess, access.grantedAt, access.lastVerified);
    }

    // Admin functions
    function updateRuleStatus(bytes32 ruleId, bool isActive) external {
        AccessRule storage rule = accessRules[ruleId];
        require(
            rule.creator == msg.sender || msg.sender == owner(),
            "Unauthorized to update rule"
        );
        
        rule.isActive = isActive;
        emit RuleUpdated(ruleId, isActive);
    }

    function setRuleCreationFee(uint256 newFee) external onlyOwner {
        ruleCreationFee = newFee;
    }

    function withdrawFees() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");

        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdrawal failed");
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // Utility functions
    function _addressToString(address addr) internal pure returns (string memory) {
        bytes32 value = bytes32(uint256(uint160(addr)));
        bytes memory alphabet = "0123456789abcdef";
        
        bytes memory str = new bytes(42);
        str[0] = '0';
        str[1] = 'x';
        
        for (uint256 i = 0; i < 20; i++) {
            str[2 + i * 2] = alphabet[uint8(value[i + 12] >> 4)];
            str[3 + i * 2] = alphabet[uint8(value[i + 12] & 0x0f)];
        }
        
        return string(str);
    }
}
