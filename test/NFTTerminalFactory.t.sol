// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {NFTTerminalFactory} from "../src/NFTTerminalFactory.sol";
import {NFTTerminal} from "../src/NFTTerminal.sol";

contract NFTTerminalFactoryTest is Test {
    NFTTerminalFactory public factory;
    address public owner = address(0x1);
    address public creator1 = address(0x2);
    address public creator2 = address(0x3);

    function setUp() public {
        vm.prank(owner);
        factory = new NFTTerminalFactory(owner);
    }

    function test_InitialState() public {
        assertEq(factory.owner(), owner);
        assertEq(factory.collectionCreationFee(), 0.01 ether);
        assertEq(factory.getCollectionCount(), 0);
        assertFalse(factory.paused());
    }

    function test_CreateCollection() public {
        vm.deal(creator1, 1 ether);
        
        vm.prank(creator1);
        factory.createCollection{value: 0.01 ether}(
            "Test Collection",
            "TEST",
            "https://api.test.com/",
            1000,
            0.001 ether
        );
        
        assertEq(factory.getCollectionCount(), 1);
        assertEq(factory.getCreatorCollectionCount(creator1), 1);
        
        address[] memory collections = factory.getCreatorCollections(creator1);
        assertEq(collections.length, 1);
        
        // Verify collection details
        (
            address creator,
            uint256 createdAt,
            bool isActive
        ) = factory.getCollectionDetails(collections[0]);
        
        assertEq(creator, creator1);
        assertGt(createdAt, 0);
        assertTrue(isActive);
        assertEq(creator, creator1);
        assertTrue(isActive);
        assertGt(createdAt, 0);
        
        // Verify the deployed contract works
        NFTTerminal collection = NFTTerminal(collections[0]);
        assertEq(collection.name(), "Test Collection");
        assertEq(collection.symbol(), "TEST");
        assertEq(collection.owner(), creator1);
        
        // Creator should manually set collection parameters
        vm.prank(creator1);
        collection.setMaxSupply(1000);
        vm.prank(creator1);
        collection.setMintPrice(0.001 ether);
        
        assertEq(collection.maxSupply(), 1000);
        assertEq(collection.mintPrice(), 0.001 ether);
    }

    function test_CreateCollection_InsufficientFee() public {
        vm.deal(creator1, 1 ether);
        
        vm.prank(creator1);
        vm.expectRevert("Insufficient creation fee");
        factory.createCollection{value: 0.005 ether}(
            "Test Collection",
            "TEST",
            "https://api.test.com/",
            1000,
            0.001 ether
        );
    }

    function test_CreateCollection_EmptyName() public {
        vm.deal(creator1, 1 ether);
        
        vm.prank(creator1);
        vm.expectRevert("Name cannot be empty");
        factory.createCollection{value: 0.01 ether}(
            "",
            "TEST",
            "https://api.test.com/",
            1000,
            0.001 ether
        );
    }

    function test_CreateCollection_EmptySymbol() public {
        vm.deal(creator1, 1 ether);
        
        vm.prank(creator1);
        vm.expectRevert("Symbol cannot be empty");
        factory.createCollection{value: 0.01 ether}(
            "Test Collection",
            "",
            "https://api.test.com/",
            1000,
            0.001 ether
        );
    }

    function test_CreateCollection_ZeroMaxSupply() public {
        vm.deal(creator1, 1 ether);
        
        vm.prank(creator1);
        vm.expectRevert("Max supply must be greater than 0");
        factory.createCollection{value: 0.01 ether}(
            "Test Collection",
            "TEST",
            "https://api.test.com/",
            0,
            0.001 ether
        );
    }

    function test_CreateCollection_RefundExcess() public {
        vm.deal(creator1, 1 ether);
        uint256 balanceBefore = creator1.balance;
        
        vm.prank(creator1);
        factory.createCollection{value: 0.015 ether}(
            "Test Collection",
            "TEST",
            "https://api.test.com/",
            1000,
            0.001 ether
        );
        
        // Should refund 0.005 ether
        assertEq(creator1.balance, balanceBefore - 0.01 ether);
    }

    function test_MultipleCollections() public {
        vm.deal(creator1, 1 ether);
        vm.deal(creator2, 1 ether);
        
        // Creator1 creates 2 collections
        vm.prank(creator1);
        factory.createCollection{value: 0.01 ether}(
            "Collection 1",
            "COL1",
            "https://api.col1.com/",
            1000,
            0.001 ether
        );
        
        vm.prank(creator1);
        factory.createCollection{value: 0.01 ether}(
            "Collection 2",
            "COL2",
            "https://api.col2.com/",
            2000,
            0.002 ether
        );
        
        // Creator2 creates 1 collection
        vm.prank(creator2);
        factory.createCollection{value: 0.01 ether}(
            "Collection 3",
            "COL3",
            "https://api.col3.com/",
            500,
            0.003 ether
        );
        
        assertEq(factory.getCollectionCount(), 3);
        assertEq(factory.getCreatorCollectionCount(creator1), 2);
        assertEq(factory.getCreatorCollectionCount(creator2), 1);
        
        address[] memory allCollections = factory.getAllCollections();
        assertEq(allCollections.length, 3);
        
        address[] memory creator1Collections = factory.getCreatorCollections(creator1);
        assertEq(creator1Collections.length, 2);
        
        address[] memory creator2Collections = factory.getCreatorCollections(creator2);
        assertEq(creator2Collections.length, 1);
    }

    function test_IsValidCollection() public {
        vm.deal(creator1, 1 ether);
        
        vm.prank(creator1);
        factory.createCollection{value: 0.01 ether}(
            "Test Collection",
            "TEST",
            "https://api.test.com/",
            1000,
            0.001 ether
        );
        
        address[] memory collections = factory.getCreatorCollections(creator1);
        assertTrue(factory.isValidCollection(collections[0]));
        assertFalse(factory.isValidCollection(address(0x999)));
    }

    function test_SetCollectionCreationFee() public {
        vm.prank(owner);
        factory.setCollectionCreationFee(0.02 ether);
        assertEq(factory.collectionCreationFee(), 0.02 ether);
    }

    function test_SetCollectionCreationFee_OnlyOwner() public {
        vm.prank(creator1);
        vm.expectRevert();
        factory.setCollectionCreationFee(0.02 ether);
    }

    function test_WithdrawFactoryFees() public {
        vm.deal(creator1, 1 ether);
        vm.deal(creator2, 1 ether);
        
        // Create collections to generate fees
        vm.prank(creator1);
        factory.createCollection{value: 0.01 ether}(
            "Collection 1",
            "COL1",
            "https://api.col1.com/",
            1000,
            0.001 ether
        );
        
        vm.prank(creator2);
        factory.createCollection{value: 0.01 ether}(
            "Collection 2",
            "COL2",
            "https://api.col2.com/",
            1000,
            0.001 ether
        );
        
        uint256 ownerBalanceBefore = owner.balance;
        
        vm.prank(owner);
        factory.withdrawFactoryFees();
        
        assertEq(owner.balance, ownerBalanceBefore + 0.02 ether);
        assertEq(address(factory).balance, 0);
    }

    function test_WithdrawFactoryFees_OnlyOwner() public {
        vm.prank(creator1);
        vm.expectRevert();
        factory.withdrawFactoryFees();
    }

    function test_DeactivateCollection() public {
        vm.deal(creator1, 1 ether);
        
        vm.prank(creator1);
        factory.createCollection{value: 0.01 ether}(
            "Test Collection",
            "TEST",
            "https://api.test.com/",
            1000,
            0.001 ether
        );
        
        address[] memory collections = factory.getCreatorCollections(creator1);
        
        vm.prank(owner);
        factory.deactivateCollection(collections[0]);
        
        (,,bool isActive) = factory.getCollectionDetails(collections[0]);
        assertFalse(isActive);
        
        vm.prank(owner);
        factory.reactivateCollection(collections[0]);
        
        (,,isActive) = factory.getCollectionDetails(collections[0]);
        assertTrue(isActive);
    }

    function test_PauseUnpause() public {
        vm.prank(owner);
        factory.pause();
        assertTrue(factory.paused());
        
        vm.deal(creator1, 1 ether);
        
        vm.prank(creator1);
        vm.expectRevert();
        factory.createCollection{value: 0.01 ether}(
            "Test Collection",
            "TEST",
            "https://api.test.com/",
            1000,
            0.001 ether
        );
        
        vm.prank(owner);
        factory.unpause();
        assertFalse(factory.paused());
        
        vm.prank(creator1);
        factory.createCollection{value: 0.01 ether}(
            "Test Collection",
            "TEST",
            "https://api.test.com/",
            1000,
            0.001 ether
        );
        
        assertEq(factory.getCollectionCount(), 1);
    }

    function test_GetFactoryStats() public {
        vm.deal(creator1, 1 ether);
        vm.deal(creator2, 1 ether);
        
        // Create multiple collections
        vm.prank(creator1);
        factory.createCollection{value: 0.01 ether}(
            "Collection 1",
            "COL1",
            "https://api.col1.com/",
            1000,
            0.001 ether
        );
        
        vm.prank(creator1);
        factory.createCollection{value: 0.01 ether}(
            "Collection 2",
            "COL2",
            "https://api.col2.com/",
            1000,
            0.001 ether
        );
        
        vm.prank(creator2);
        factory.createCollection{value: 0.01 ether}(
            "Collection 3",
            "COL3",
            "https://api.col3.com/",
            1000,
            0.001 ether
        );
        
        (
            uint256 totalCollections,
            uint256 totalCreators,
            uint256 totalFees
        ) = factory.getFactoryStats();
        
        assertEq(totalCollections, 3);
        assertEq(totalCreators, 0); // Simplified - no longer tracking unique creators
        assertEq(totalFees, 0.03 ether);
    }

    function test_CollectionFunctionality() public {
        vm.deal(creator1, 1 ether);
        vm.deal(creator2, 1 ether);
        
        // Create collection
        vm.prank(creator1);
        factory.createCollection{value: 0.01 ether}(
            "Functional Test",
            "FUNC",
            "https://api.functional.com/",
            100,
            0.01 ether
        );
        
        address[] memory collections = factory.getCreatorCollections(creator1);
        NFTTerminal collection = NFTTerminal(collections[0]);
        
        // Test that creator is owner of the collection
        assertEq(collection.owner(), creator1);
        
        // Creator sets up the collection
        vm.prank(creator1);
        collection.setMaxSupply(100);
        vm.prank(creator1);
        collection.setMintPrice(0.01 ether);
        
        // Test minting as owner
        vm.prank(creator1);
        collection.ownerMint(creator2, 5);
        assertEq(collection.balanceOf(creator2), 5);
        
        // Test public minting
        vm.prank(creator1);
        collection.setMintPhase(NFTTerminal.MintPhase.PUBLIC);
        
        vm.prank(creator2);
        collection.publicMint{value: 0.03 ether}(3);
        assertEq(collection.balanceOf(creator2), 8);
        
        // Test token gating
        vm.prank(creator2);
        collection.grantTokenGatedAccess(0, "premium-access");
        assertTrue(collection.hasTokenGatedAccess(0, "premium-access"));
    }
}
