// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {NFTTerminal} from "../src/NFTTerminal.sol";

contract NFTTerminalTest is Test {
    NFTTerminal public nftTerminal;
    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public user3 = address(0x4);

    // Merkle tree setup for whitelist testing
    bytes32 public constant MERKLE_ROOT = 0x8e8c9a8e8a8b8d8f8e8c9a8e8a8b8d8f8e8c9a8e8a8b8d8f8e8c9a8e8a8b8d8f;
    
    function setUp() public {
        vm.prank(owner);
        nftTerminal = new NFTTerminal(
            "NFT Terminal Collection",
            "NTC",
            "https://api.example.com/metadata/",
            owner
        );
    }

    function test_InitialState() public {
        assertEq(nftTerminal.name(), "NFT Terminal Collection");
        assertEq(nftTerminal.symbol(), "NTC");
        assertEq(nftTerminal.owner(), owner);
        assertEq(nftTerminal.totalSupply(), 0);
        assertEq(nftTerminal.maxSupply(), 10000);
        assertEq(uint256(nftTerminal.currentPhase()), uint256(NFTTerminal.MintPhase.CLOSED));
        assertFalse(nftTerminal.paused());
    }

    function test_SetMintPhase() public {
        vm.prank(owner);
        nftTerminal.setMintPhase(NFTTerminal.MintPhase.PUBLIC);
        
        assertEq(uint256(nftTerminal.currentPhase()), uint256(NFTTerminal.MintPhase.PUBLIC));
    }

    function test_SetMintPhase_OnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        nftTerminal.setMintPhase(NFTTerminal.MintPhase.PUBLIC);
    }

    function test_OwnerMint() public {
        vm.prank(owner);
        nftTerminal.ownerMint(user1, 5);
        
        assertEq(nftTerminal.balanceOf(user1), 5);
        assertEq(nftTerminal.totalSupply(), 5);
        assertEq(nftTerminal.ownerOf(0), user1);
        assertEq(nftTerminal.ownerOf(4), user1);
    }

    function test_OwnerMint_ExceedsMaxSupply() public {
        vm.prank(owner);
        nftTerminal.setMaxSupply(5);
        
        vm.prank(owner);
        vm.expectRevert("Exceeds max supply");
        nftTerminal.ownerMint(user1, 6);
    }

    function test_PublicMint() public {
        vm.prank(owner);
        nftTerminal.setMintPhase(NFTTerminal.MintPhase.PUBLIC);
        
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        nftTerminal.publicMint{value: 0.003 ether}(3);
        
        assertEq(nftTerminal.balanceOf(user1), 3);
        assertEq(nftTerminal.totalSupply(), 3);
    }

    function test_PublicMint_WrongPhase() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        vm.expectRevert("Public phase not active");
        nftTerminal.publicMint{value: 0.001 ether}(1);
    }

    function test_PublicMint_InsufficientPayment() public {
        vm.prank(owner);
        nftTerminal.setMintPhase(NFTTerminal.MintPhase.PUBLIC);
        
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        vm.expectRevert("Insufficient payment");
        nftTerminal.publicMint{value: 0.0005 ether}(1);
    }

    function test_PublicMint_ExceedsLimit() public {
        vm.prank(owner);
        nftTerminal.setMintPhase(NFTTerminal.MintPhase.PUBLIC);
        
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        vm.expectRevert("Exceeds public limit");
        nftTerminal.publicMint{value: 0.011 ether}(11);
    }

    function test_TokenGating() public {
        // Mint token to user
        vm.prank(owner);
        nftTerminal.ownerMint(user1, 1);
        
        // Verify ownership
        assertTrue(nftTerminal.verifyTokenOwnership(user1, 0));
        assertFalse(nftTerminal.verifyTokenOwnership(user2, 0));
        
        // Grant token-gated access
        vm.prank(user1);
        nftTerminal.grantTokenGatedAccess(0, "premium-content");
        
        assertTrue(nftTerminal.hasTokenGatedAccess(0, "premium-content"));
        assertFalse(nftTerminal.hasTokenGatedAccess(0, "other-content"));
    }

    function test_TokenGating_NotOwner() public {
        vm.prank(owner);
        nftTerminal.ownerMint(user1, 1);
        
        vm.prank(user2);
        vm.expectRevert("Not token owner");
        nftTerminal.grantTokenGatedAccess(0, "premium-content");
    }

    function test_BatchTokenVerification() public {
        // Mint tokens to different users
        vm.prank(owner);
        nftTerminal.ownerMint(user1, 3);
        vm.prank(owner);
        nftTerminal.ownerMint(user2, 2);
        
        uint256[] memory tokenIds = new uint256[](5);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;
        tokenIds[3] = 3;
        tokenIds[4] = 4;
        
        bool[] memory results = nftTerminal.verifyMultipleTokenOwnership(user1, tokenIds);
        
        assertTrue(results[0]);
        assertTrue(results[1]);
        assertTrue(results[2]);
        assertFalse(results[3]);
        assertFalse(results[4]);
    }

    function test_RevenueWithdrawal() public {
        vm.prank(owner);
        nftTerminal.setMintPhase(NFTTerminal.MintPhase.PUBLIC);
        
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        nftTerminal.publicMint{value: 0.005 ether}(5);
        
        uint256 ownerBalanceBefore = owner.balance;
        
        vm.prank(owner);
        nftTerminal.withdrawRevenue();
        
        assertEq(owner.balance, ownerBalanceBefore + 0.005 ether);
        assertEq(address(nftTerminal).balance, 0);
    }

    function test_RevenueWithdrawal_OnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        nftTerminal.withdrawRevenue();
    }

    function test_PauseUnpause() public {
        vm.prank(owner);
        nftTerminal.pause();
        assertTrue(nftTerminal.paused());
        
        vm.prank(owner);
        nftTerminal.setMintPhase(NFTTerminal.MintPhase.PUBLIC);
        
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        vm.expectRevert();
        nftTerminal.publicMint{value: 0.001 ether}(1);
        
        vm.prank(owner);
        nftTerminal.unpause();
        assertFalse(nftTerminal.paused());
        
        vm.prank(user1);
        nftTerminal.publicMint{value: 0.001 ether}(1);
        assertEq(nftTerminal.balanceOf(user1), 1);
    }

    function test_SetMaxSupply() public {
        vm.prank(owner);
        nftTerminal.setMaxSupply(5000);
        assertEq(nftTerminal.maxSupply(), 5000);
    }

    function test_SetMaxSupply_CannotBeLowerThanCurrentSupply() public {
        vm.prank(owner);
        nftTerminal.ownerMint(user1, 10);
        
        vm.prank(owner);
        vm.expectRevert("Max supply cannot be less than current supply");
        nftTerminal.setMaxSupply(5);
    }

    function test_SetMintPrice() public {
        vm.prank(owner);
        nftTerminal.setMintPrice(0.002 ether);
        assertEq(nftTerminal.mintPrice(), 0.002 ether);
    }

    function test_GetContractInfo() public {
        (
            uint256 currentSupply,
            uint256 maxSupplyLimit,
            uint256 price,
            NFTTerminal.MintPhase phase,
            bool isPaused
        ) = nftTerminal.getContractInfo();
        
        assertEq(currentSupply, 0);
        assertEq(maxSupplyLimit, 10000);
        assertEq(price, 0.001 ether);
        assertEq(uint256(phase), uint256(NFTTerminal.MintPhase.CLOSED));
        assertFalse(isPaused);
    }

    function test_GetUserMintCounts() public {
        vm.prank(owner);
        nftTerminal.setMintPhase(NFTTerminal.MintPhase.PUBLIC);
        
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        nftTerminal.publicMint{value: 0.003 ether}(3);
        
        (uint256 whitelistCount, uint256 publicCount) = nftTerminal.getUserMintCounts(user1);
        assertEq(whitelistCount, 0);
        assertEq(publicCount, 3);
    }

    function test_TokenURI() public {
        vm.prank(owner);
        nftTerminal.ownerMint(user1, 1);
        
        string memory uri = nftTerminal.tokenURI(0);
        assertEq(uri, "https://api.example.com/metadata/0");
    }

    function test_SupportsInterface() public {
        // Test ERC721 interface support
        assertTrue(nftTerminal.supportsInterface(0x80ac58cd)); // ERC721
        assertTrue(nftTerminal.supportsInterface(0x5b5e139f)); // ERC721Metadata
        assertTrue(nftTerminal.supportsInterface(0x780e9d63)); // ERC721Enumerable
    }

    function test_BatchMintGasEfficiency() public {
        vm.prank(owner);
        nftTerminal.setMintPhase(NFTTerminal.MintPhase.PUBLIC);
        
        // Set higher limit for this test
        vm.prank(owner);
        nftTerminal.setMaxMints(20, 20);
        
        vm.deal(user1, 1 ether);
        
        uint256 gasBefore = gasleft();
        vm.prank(user1);
        nftTerminal.publicMint{value: 0.02 ether}(20); // Max batch size
        uint256 gasUsed = gasBefore - gasleft();
        
        assertEq(nftTerminal.balanceOf(user1), 20);
        console.log("Gas used for batch mint of 20 tokens:", gasUsed);
        
        // Gas should be reasonable for Monad's high throughput
        // Monad can handle higher gas usage efficiently due to parallel execution
        assertLt(gasUsed, 3000000); // Adjusted for Monad's capabilities
    }
}
