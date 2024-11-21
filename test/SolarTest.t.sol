// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {FundNFT} from "../src/SolarFund.sol";
import {IERC1155Receiver, IERC165} from "lib/openzeppelin-contracts/contracts/token/ERC1155/IERC1155Receiver.sol";
import {ERC165} from "lib/openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";

contract FundNFTTest is Test, IERC1155Receiver, ERC165 {
    FundNFT private fundNFT;
    address private owner;
    address private user1;
    address private user2;

    // Add a receive function to accept ETH in this contract
    receive() external payable {}

    function setUp() public {
        owner = address(this); // Test contract will act as the owner
        user1 = vm.addr(1); // User1 for interacting with the contract
        user2 = vm.addr(2); // User2 for interacting with the contract

        // Deploy the FundNFT contract with a base URI
        string memory baseURI = "ipfs://QmYourIpfsHash/";
        fundNFT = new FundNFT(baseURI);

        // Fund users with some ETH for testing
        vm.deal(user1, 1 ether);
        vm.deal(user2, 1 ether);
    }

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external override returns (bytes4) {
        return this.onERC1155Received.selector; // Required to indicate the receipt was successful
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external override returns (bytes4) {
        return this.onERC1155BatchReceived.selector; // Required for batch transfers
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC1155Receiver).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    // Test the creation of a fund
    function testCreateFund() public {
        uint256 initialFundId = fundNFT.getCurrentFundId();
        uint256 nftSupply = 10;
        uint256 nftPrice = 0.05 ether;
        string memory fundBaseURI = "https://mybaseuri.com/fund1/{id}.json";

        // Owner creates a new fund
        uint256 newFundId = fundNFT.createFund(
            nftSupply,
            fundBaseURI,
            nftPrice
        );

        assertEq(newFundId, initialFundId + 1);

        // Verify that the fund has been created with correct values
        (
            uint256 tokenId,
            uint256 totalSupply,
            uint256 availableSupply,
            string memory baseURI,
            uint256 price
        ) = fundNFT.getFundDetails(newFundId);
        assertEq(tokenId, 1); // Token ID should be 1
        assertEq(totalSupply, nftSupply); // Total supply should match the input
        assertEq(availableSupply, nftSupply); // Available supply should also match
        assertEq(baseURI, fundBaseURI);
        assertEq(price, nftPrice);
    }

    // Test purchasing an NFT
    function testBuyNFT() public {
        // Owner creates a new fund
        uint256 fundId = fundNFT.createFund(
            20, // NFT supply
            "https://mybaseuri.com/fund1/{id}.json", // FundNFT URI
            0.05 ether // NFT Price
        );

        // Make sure the contract holds the tokens
        uint256 initialContractBalance = fundNFT.balanceOf(
            address(fundNFT),
            fundId
        );
        console.log("Initial Contract Balance: ", initialContractBalance);
        assertEq(initialContractBalance, 20); // Contract should hold 20 tokens

        // User1 purchases an NFT by sending 0.5 ETH
        uint256 purchaseQuantity = 10;
        vm.prank(user1); // Simulate the transaction coming from user1
        vm.deal(user1, 10 ether);

        fundNFT.buyNFT{value: 0.5 ether}(fundId, purchaseQuantity);

        // Verify that the user's NFT balance has increased
        uint256 userBalance = fundNFT.balanceOf(user1, fundId);
        console.log("User NFT Balance after purchase: ", userBalance);
        assertEq(userBalance, purchaseQuantity);

        // Verify that the fund's available supply has decreased
        (, , uint256 availableSupply, , ) = fundNFT.getFundDetails(fundId);
        console.log("Available Supply after purchase: ", availableSupply);
        assertEq(availableSupply, 10); // 20 - 10 = 10

        // Verify that the contract's balance of NFTs has decreased
        uint256 finalContractBalance = fundNFT.balanceOf(
            address(fundNFT),
            fundId
        );
        console.log("Final Contract Balance: ", finalContractBalance);
        assertEq(finalContractBalance, 10);

        // Verify that any excess Ether is refunded
        uint256 excessEther = user1.balance;
        console.log("User Balance After Purchase: ", excessEther);
        assertEq(excessEther, 9.5 ether); // 10 - 0.5 = 9.5
    }

    // Test withdraw function
    function testWithdrawFunds() public {
        uint256 nftSupply = 10;
        uint256 nftPrice = 0.05 ether;

        // Owner creates a new fund
        fundNFT.createFund(
            nftSupply,
            "https://mybaseuri.com/fund1/{id}.json",
            nftPrice
        );

        // User1 purchases an NFT by sending 0.05 ETH
        vm.prank(user1);
        fundNFT.buyNFT{value: 0.05 ether}(1, 1);

        uint256 contractBalanceAfterPurchase = address(fundNFT).balance;
        assertEq(contractBalanceAfterPurchase, 0.05 ether);

        console.log(address(this).balance);
        console.log(user1.balance);

        // Owner withdraws the funds
        uint256 ownerInitialBalance = owner.balance;
        fundNFT.withdrawFunds();
        uint256 ownerFinalBalance = owner.balance;

        // Verify that the owner's balance has increased by 0.05 ETH
        assertEq(ownerFinalBalance - ownerInitialBalance, 0.05 ether);

        uint256 contractBalanceAfterWithdrawal = address(fundNFT).balance;
        assertEq(contractBalanceAfterWithdrawal, 0);
    }

    // Test failure cases
    function testFailBuyNFTWithoutSendingETH() public {
        uint256 nftSupply = 10;
        uint256 nftPrice = 0.05 ether;

        // Owner creates a new fund
        fundNFT.createFund(
            nftSupply,
            "https://mybaseuri.com/fund1/{id}.json",
            nftPrice
        );

        // User2 tries to buy an NFT without sending 0.05 ETH (should fail)
        vm.prank(user2);
        fundNFT.buyNFT(1, 1); // Should revert since no ETH is sent
    }

    function testFailBuyNFTWhenNoSupply() public {
        uint256 nftSupply = 1;
        uint256 nftPrice = 0.05 ether;

        // Owner creates a new fund with only 1 NFT available
        fundNFT.createFund(
            nftSupply,
            "https://mybaseuri.com/fund1/{id}.json",
            nftPrice
        );

        // User1 buys the first NFT
        vm.prank(user1);
        fundNFT.buyNFT{value: 0.05 ether}(1, 1);

        // User2 tries to buy another NFT from the same fund (should fail as supply is 0)
        vm.prank(user2);
        fundNFT.buyNFT{value: 0.05 ether}(1, 1); // Should fail
    }

    // Test constructing metadata URL
    // function testConstructMetadataURL() public {
    //     uint256 nftSupply = 10; // For example, create 10 NFTs
    //     uint256 nftPrice = 0.05 ether;
    //     uint256 fundId = fundNFT.createFund(
    //         nftSupply,
    //         "https://mybaseuri.com/fund1/{id}.json",
    //         nftPrice
    //     ); // This will create a fund and mint NFTs
    //     uint256 tokenId = fundNFT.getCurrentTokenId(); // Assuming this is how you get the token ID

    //     // Construct the expected metadata URL
    //     string memory expectedURL = "ipfs://QmYourIpfsHash/1.json";
    //     // string(
    //     //     abi.encodePacked(
    //     //         "ipfs://QmYourIpfsHash/",
    //     //         Strings.toString(tokenId),
    //     //         ".json"
    //     //     )
    //     // );

    //     // Call the constructMetadataURL function
    //     string memory metadataURL = fundNFT.constructMetadataURL(
    //         fundId,
    //         tokenId
    //     );

    //     // Verify that the constructed URL is correct
    //     assertEq(metadataURL, expectedURL);
    // }

    // Test getCurrentTokenId
    function testGetCurrentTokenId() public {
        fundNFT.createFund(
            10,
            "https://mybaseuri.com/fund1/{id}.json",
            0.05 ether
        ); // Creates a fund with 10 NFTs
        uint256 tokenId = fundNFT.getCurrentTokenId();

        // Verify that the current token ID matches the expected value
        assertEq(tokenId, 1); // Assuming the first tokenId is 1 when the contract is deployed
    }

    // Test getCurrentFundId
    function testGetCurrentFundId() public {
        fundNFT.createFund(
            10,
            "https://mybaseuri.com/fund1/{id}.json",
            0.05 ether
        ); // Creates a fund with 10 NFTs
        uint256 fundId = fundNFT.getCurrentFundId();

        // Verify that the current fund ID matches the expected value
        assertEq(fundId, 1); // Assuming the first fundId is 1 when the contract is deployed
    }

    // Test getFundDetails
    function testGetFundDetails() public {
        uint256 nftSupply = 10;
        string memory fundBaseURI = "https://mybaseuri.com/fund1/{id}.json";
        uint256 nftPrice = 0.05 ether;

        // Owner creates a new fund
        fundNFT.createFund(nftSupply, fundBaseURI, nftPrice);

        // Get details of the created fund
        (
            uint256 tokenId,
            uint256 totalSupply,
            uint256 availableSupply,
            string memory baseURI,
            uint256 price
        ) = fundNFT.getFundDetails(1);

        // Verify that the fund details are correct
        assertEq(tokenId, 1); // Token ID should be 1
        assertEq(totalSupply, nftSupply); // Total supply should match the input
        assertEq(availableSupply, nftSupply); // Available supply should also match
        assertEq(baseURI, fundBaseURI); // NFT Uri must match
        assertEq(price, nftPrice); // Price of the NFT must match
    }

    // // Test getMetadataURL
    // function testGetMetadataURL() public {
    //     uint256 nftSupply = 10; // Supply of 10 NFTs
    //     uint256 fundId = fundNFT.createFund(
    //         nftSupply,
    //         "https://mybaseuri.com/fund1/{id}.json"
    //     ); // Create the fund and mint NFTs

    //     uint256 tokenId = fundNFT.getCurrentTokenId(); // Get the valid token ID for this fund

    //     // Construct the expected metadata URL with the base URI and token ID
    //     string memory expectedURL = string(
    //         abi.encodePacked(
    //             "https://mybaseuri.com/fund1/",
    //             uint2str(tokenId),
    //             ".json"
    //         )
    //     );

    //     // Call the constructMetadataURL function
    //     string memory metadataURL = fundNFT.getMetadataURL(fundId, tokenId);

    //     // Verify that the constructed URL is correct
    //     assertEq(metadataURL, expectedURL);
    // }

    // Test failure cases for invalid fund ID
    function testFailGetFundDetailsForInvalidFundId() public {
        // Attempt to get fund details for an invalid fund ID (should revert)
        fundNFT.getFundDetails(999); // Should revert because fund 999 doesn't exist
    }

    // Test failure cases for invalid tokenId in metadata URL
    function testFailConstructMetadataURLForInvalidTokenId() public {
        // Test for a tokenId that is invalid (if tokenId > currentTokenId)
        uint256 invalidTokenId = 999;
        uint256 invalidFundId = 200;
        fundNFT.constructMetadataURL(invalidFundId, invalidTokenId); // Should revert if the token doesn't exist
    }
}
