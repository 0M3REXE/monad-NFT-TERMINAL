// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {TokenGatingVerifier} from "../src/TokenGatingVerifier.sol";
import {NFTTerminal} from "../src/NFTTerminal.sol";

contract TokenGatingVerifierTest is Test {
    TokenGatingVerifier public verifier;
    NFTTerminal public collection1;
    NFTTerminal public collection2;
    
    address public owner = address(0x1);
    address public creator = address(0x2);
    address public user1 = address(0x3);
    address public user2 = address(0x4);

    function setUp() public {
        vm.prank(owner);
        verifier = new TokenGatingVerifier(owner);
        
        // Deploy test NFT collections
        vm.prank(creator);
        collection1 = new NFTTerminal(
            "Test Collection 1",
            "TC1",
            "https://api.test1.com/",
            creator
        );
        
        vm.prank(creator);
        collection2 = new NFTTerminal(
            "Test Collection 2",
            "TC2",
            "https://api.test2.com/",
            creator
        );
        
        // Mint some tokens for testing
        vm.prank(creator);
        collection1.ownerMint(user1, 5);
        
        vm.prank(creator);
        collection1.ownerMint(user2, 2);
        
        vm.prank(creator);
        collection2.ownerMint(user1, 3);
    }

    function test_InitialState() public {
        assertEq(verifier.owner(), owner);
        assertEq(verifier.ruleCreationFee(), 0.001 ether);
        assertFalse(verifier.paused());
        
        bytes32[] memory allRules = verifier.getAllRules();
        assertEq(allRules.length, 0);
    }

    function test_CreateAccessRule() public {
        address[] memory collections = new address[](2);
        collections[0] = address(collection1);
        collections[1] = address(collection2);
        
        uint256[] memory minimums = new uint256[](2);
        minimums[0] = 2;
        minimums[1] = 1;
        
        vm.deal(creator, 1 ether);
        
        vm.prank(creator);
        bytes32 ruleId = verifier.createAccessRule{value: 0.001 ether}(
            "discord",
            "Premium Discord Role",
            collections,
            minimums,
            0 // No expiry
        );
        
        // Verify rule was created
        (
            string memory contentType,
            string memory description,
            address[] memory requiredCollections,
            uint256[] memory minimumTokens,
            address ruleCreator,
            bool isActive,
            uint256 createdAt,
            uint256 expiryTime
        ) = verifier.getAccessRule(ruleId);
        
        assertEq(contentType, "discord");
        assertEq(description, "Premium Discord Role");
        assertEq(requiredCollections.length, 2);
        assertEq(requiredCollections[0], address(collection1));
        assertEq(requiredCollections[1], address(collection2));
        assertEq(minimumTokens[0], 2);
        assertEq(minimumTokens[1], 1);
        assertEq(ruleCreator, creator);
        assertTrue(isActive);
        assertGt(createdAt, 0);
        assertEq(expiryTime, 0);
        
        bytes32[] memory allRules = verifier.getAllRules();
        assertEq(allRules.length, 1);
        
        bytes32[] memory creatorRules = verifier.getCreatorRules(creator);
        assertEq(creatorRules.length, 1);
        assertEq(creatorRules[0], ruleId);
    }

    function test_CreateAccessRule_InsufficientFee() public {
        address[] memory collections = new address[](1);
        collections[0] = address(collection1);
        
        uint256[] memory minimums = new uint256[](1);
        minimums[0] = 1;
        
        vm.deal(creator, 1 ether);
        
        vm.prank(creator);
        vm.expectRevert("Insufficient fee");
        verifier.createAccessRule{value: 0.0005 ether}(
            "discord",
            "Test Rule",
            collections,
            minimums,
            0
        );
    }

    function test_CreateAccessRule_EmptyContentType() public {
        address[] memory collections = new address[](1);
        collections[0] = address(collection1);
        
        uint256[] memory minimums = new uint256[](1);
        minimums[0] = 1;
        
        vm.deal(creator, 1 ether);
        
        vm.prank(creator);
        vm.expectRevert("Content type required");
        verifier.createAccessRule{value: 0.001 ether}(
            "",
            "Test Rule",
            collections,
            minimums,
            0
        );
    }

    function test_CreateAccessRule_ArrayLengthMismatch() public {
        address[] memory collections = new address[](2);
        collections[0] = address(collection1);
        collections[1] = address(collection2);
        
        uint256[] memory minimums = new uint256[](1);
        minimums[0] = 1;
        
        vm.deal(creator, 1 ether);
        
        vm.prank(creator);
        vm.expectRevert("Array length mismatch");
        verifier.createAccessRule{value: 0.001 ether}(
            "discord",
            "Test Rule",
            collections,
            minimums,
            0
        );
    }

    function test_VerifyAccess_Success() public {
        // Create access rule requiring 2 tokens from collection1 and 1 from collection2
        address[] memory collections = new address[](2);
        collections[0] = address(collection1);
        collections[1] = address(collection2);
        
        uint256[] memory minimums = new uint256[](2);
        minimums[0] = 2;
        minimums[1] = 1;
        
        vm.deal(creator, 1 ether);
        
        vm.prank(creator);
        bytes32 ruleId = verifier.createAccessRule{value: 0.001 ether}(
            "discord",
            "Premium Access",
            collections,
            minimums,
            0
        );
        
        // user1 has 5 tokens from collection1 and 3 from collection2 - should pass
        (bool hasAccess, string memory details) = verifier.verifyAccess(ruleId, user1);
        assertTrue(hasAccess);
        assertEq(details, "Access granted");
        
        // user2 has 2 tokens from collection1 and 0 from collection2 - should fail
        (hasAccess, details) = verifier.verifyAccess(ruleId, user2);
        assertFalse(hasAccess);
        assertTrue(bytes(details).length > 0);
    }

    function test_VerifyAccess_InactiveRule() public {
        address[] memory collections = new address[](1);
        collections[0] = address(collection1);
        
        uint256[] memory minimums = new uint256[](1);
        minimums[0] = 1;
        
        vm.deal(creator, 1 ether);
        
        vm.prank(creator);
        bytes32 ruleId = verifier.createAccessRule{value: 0.001 ether}(
            "discord",
            "Test Rule",
            collections,
            minimums,
            0
        );
        
        // Deactivate rule
        vm.prank(creator);
        verifier.updateRuleStatus(ruleId, false);
        
        (bool hasAccess, string memory details) = verifier.verifyAccess(ruleId, user1);
        assertFalse(hasAccess);
        assertEq(details, "Rule is not active");
    }

    function test_VerifyAccess_ExpiredRule() public {
        address[] memory collections = new address[](1);
        collections[0] = address(collection1);
        
        uint256[] memory minimums = new uint256[](1);
        minimums[0] = 1;
        
        vm.deal(creator, 1 ether);
        
        vm.prank(creator);
        bytes32 ruleId = verifier.createAccessRule{value: 0.001 ether}(
            "discord",
            "Test Rule",
            collections,
            minimums,
            block.timestamp + 100 // Expires in 100 seconds
        );
        
        // Fast forward past expiry
        vm.warp(block.timestamp + 200);
        
        (bool hasAccess, string memory details) = verifier.verifyAccess(ruleId, user1);
        assertFalse(hasAccess);
        assertEq(details, "Rule has expired");
    }

    function test_GrantAccess() public {
        address[] memory collections = new address[](1);
        collections[0] = address(collection1);
        
        uint256[] memory minimums = new uint256[](1);
        minimums[0] = 2;
        
        vm.deal(creator, 1 ether);
        
        vm.prank(creator);
        bytes32 ruleId = verifier.createAccessRule{value: 0.001 ether}(
            "discord",
            "Test Access",
            collections,
            minimums,
            0
        );
        
        // Grant access to user1 (who has 5 tokens)
        vm.prank(creator);
        verifier.grantAccess(ruleId, user1);
        
        (bool hasAccess, uint256 grantedAt, uint256 lastVerified) = verifier.getUserAccessInfo(ruleId, user1);
        assertTrue(hasAccess);
        assertGt(grantedAt, 0);
        assertGt(lastVerified, 0);
        
        assertTrue(verifier.hasContentTypeAccess(user1, "discord"));
    }

    function test_GrantAccess_UnauthorizedCreator() public {
        address[] memory collections = new address[](1);
        collections[0] = address(collection1);
        
        uint256[] memory minimums = new uint256[](1);
        minimums[0] = 1;
        
        vm.deal(creator, 1 ether);
        
        vm.prank(creator);
        bytes32 ruleId = verifier.createAccessRule{value: 0.001 ether}(
            "discord",
            "Test Rule",
            collections,
            minimums,
            0
        );
        
        vm.prank(user1);
        vm.expectRevert("Only rule creator can grant access");
        verifier.grantAccess(ruleId, user2);
    }

    function test_RevokeAccess() public {
        address[] memory collections = new address[](1);
        collections[0] = address(collection1);
        
        uint256[] memory minimums = new uint256[](1);
        minimums[0] = 1;
        
        vm.deal(creator, 1 ether);
        
        vm.prank(creator);
        bytes32 ruleId = verifier.createAccessRule{value: 0.001 ether}(
            "discord",
            "Test Access",
            collections,
            minimums,
            0
        );
        
        // Grant then revoke access
        vm.prank(creator);
        verifier.grantAccess(ruleId, user1);
        
        vm.prank(creator);
        verifier.revokeAccess(ruleId, user1);
        
        (bool hasAccess,,) = verifier.getUserAccessInfo(ruleId, user1);
        assertFalse(hasAccess);
        
        assertFalse(verifier.hasContentTypeAccess(user1, "discord"));
    }

    function test_BatchVerifyAccess() public {
        address[] memory collections = new address[](1);
        collections[0] = address(collection1);
        
        uint256[] memory minimums = new uint256[](1);
        minimums[0] = 3;
        
        vm.deal(creator, 1 ether);
        
        vm.prank(creator);
        bytes32 ruleId = verifier.createAccessRule{value: 0.001 ether}(
            "event",
            "Event Access",
            collections,
            minimums,
            0
        );
        
        address[] memory users = new address[](2);
        users[0] = user1; // Has 5 tokens - should pass
        users[1] = user2; // Has 2 tokens - should fail
        
        bool[] memory results = verifier.batchVerifyAccess(ruleId, users);
        
        assertEq(results.length, 2);
        assertTrue(results[0]);  // user1 passes
        assertFalse(results[1]); // user2 fails
    }

    function test_UpdateRuleStatus() public {
        address[] memory collections = new address[](1);
        collections[0] = address(collection1);
        
        uint256[] memory minimums = new uint256[](1);
        minimums[0] = 1;
        
        vm.deal(creator, 1 ether);
        
        vm.prank(creator);
        bytes32 ruleId = verifier.createAccessRule{value: 0.001 ether}(
            "discord",
            "Test Rule",
            collections,
            minimums,
            0
        );
        
        // Deactivate rule
        vm.prank(creator);
        verifier.updateRuleStatus(ruleId, false);
        
        (,,,,,bool isActive,,) = verifier.getAccessRule(ruleId);
        assertFalse(isActive);
        
        // Reactivate rule
        vm.prank(creator);
        verifier.updateRuleStatus(ruleId, true);
        
        (,,,,,isActive,,) = verifier.getAccessRule(ruleId);
        assertTrue(isActive);
    }

    function test_UpdateRuleStatus_OnlyCreatorOrOwner() public {
        address[] memory collections = new address[](1);
        collections[0] = address(collection1);
        
        uint256[] memory minimums = new uint256[](1);
        minimums[0] = 1;
        
        vm.deal(creator, 1 ether);
        
        vm.prank(creator);
        bytes32 ruleId = verifier.createAccessRule{value: 0.001 ether}(
            "discord",
            "Test Rule",
            collections,
            minimums,
            0
        );
        
        vm.prank(user1);
        vm.expectRevert("Unauthorized to update rule");
        verifier.updateRuleStatus(ruleId, false);
        
        // Owner should be able to update
        vm.prank(owner);
        verifier.updateRuleStatus(ruleId, false);
        
        (,,,,,bool isActive,,) = verifier.getAccessRule(ruleId);
        assertFalse(isActive);
    }

    function test_SetRuleCreationFee() public {
        vm.prank(owner);
        verifier.setRuleCreationFee(0.002 ether);
        assertEq(verifier.ruleCreationFee(), 0.002 ether);
    }

    function test_WithdrawFees() public {
        // Create some rules to generate fees
        address[] memory collections = new address[](1);
        collections[0] = address(collection1);
        
        uint256[] memory minimums = new uint256[](1);
        minimums[0] = 1;
        
        vm.deal(creator, 1 ether);
        
        vm.prank(creator);
        verifier.createAccessRule{value: 0.001 ether}(
            "discord",
            "Rule 1",
            collections,
            minimums,
            0
        );
        
        vm.prank(creator);
        verifier.createAccessRule{value: 0.001 ether}(
            "event",
            "Rule 2",
            collections,
            minimums,
            0
        );
        
        uint256 ownerBalanceBefore = owner.balance;
        
        vm.prank(owner);
        verifier.withdrawFees();
        
        assertEq(owner.balance, ownerBalanceBefore + 0.002 ether);
        assertEq(address(verifier).balance, 0);
    }

    function test_PauseUnpause() public {
        vm.prank(owner);
        verifier.pause();
        assertTrue(verifier.paused());
        
        address[] memory collections = new address[](1);
        collections[0] = address(collection1);
        
        uint256[] memory minimums = new uint256[](1);
        minimums[0] = 1;
        
        vm.deal(creator, 1 ether);
        
        vm.prank(creator);
        vm.expectRevert();
        verifier.createAccessRule{value: 0.001 ether}(
            "discord",
            "Test Rule",
            collections,
            minimums,
            0
        );
        
        vm.prank(owner);
        verifier.unpause();
        assertFalse(verifier.paused());
        
        vm.prank(creator);
        verifier.createAccessRule{value: 0.001 ether}(
            "discord",
            "Test Rule",
            collections,
            minimums,
            0
        );
        
        bytes32[] memory allRules = verifier.getAllRules();
        assertEq(allRules.length, 1);
    }
}
