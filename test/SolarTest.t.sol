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
        string memory fundBaseURI = "https://mybaseuri.com/fund1/{id}.json";

        // Owner creates a new fund
        fundNFT.createFund(nftSupply, fundBaseURI);

        // Verify that the fund has been created with correct values
        (
            uint256 tokenId,
            uint256 totalSupply,
            uint256 availableSupply,
            string memory baseURI
        ) = fundNFT.getFundDetails(initialFundId + 1);
        assertEq(tokenId, 1); // Token ID should be 1
        assertEq(totalSupply, nftSupply); // Total supply should match the input
        assertEq(availableSupply, nftSupply); // Available supply should also match
    }

    // Test purchasing an NFT
    function testBuyNFT() public {
        // Owner creates a new fund
        uint256 tokenId = fundNFT.createFund(
            10,
            "https://mybaseuri.com/fund1/{id}.json"
        );

        // Make sure the contract holds the tokens
        uint256 contractBalance = fundNFT.balanceOf(address(fundNFT), tokenId);
        assertEq(contractBalance, 10); // Contract should hold 10 tokens

        // User1 purchases an NFT by sending 0.1 ETH
        vm.prank(user1); // Simulate the transaction coming from user1
        vm.deal(user1, 1 ether);
        fundNFT.buyNFT{value: 0.05 ether}(1);

        // Verify that the user's NFT balance has increased
        uint256 userBalance = fundNFT.balanceOf(user1, tokenId);
        assertEq(userBalance, tokenId);

        // Verify that the fund's available supply has decreased
        (, , uint256 availableSupply, ) = fundNFT.getFundDetails(tokenId);
        assertEq(availableSupply, 9);
    }

    // Test withdraw function
    function testWithdrawFunds() public {
        uint256 nftSupply = 10;

        // Owner creates a new fund
        fundNFT.createFund(nftSupply, "https://mybaseuri.com/fund1/{id}.json");

        // User1 purchases an NFT by sending 0.1 ETH
        vm.prank(user1);
        fundNFT.buyNFT{value: 0.05 ether}(1);
        console.log(address(this).balance);
        console.log(user1.balance);

        // Owner withdraws the funds
        uint256 ownerInitialBalance = owner.balance;
        fundNFT.withdrawFunds();
        uint256 ownerFinalBalance = owner.balance;

        // Verify that the owner's balance has increased by 0.1 ETH
        assertEq(ownerFinalBalance - ownerInitialBalance, 0.05 ether);
    }

    // Test failure cases
    function testFailBuyNFTWithoutSendingETH() public {
        uint256 nftSupply = 10;

        // Owner creates a new fund
        fundNFT.createFund(nftSupply, "https://mybaseuri.com/fund1/{id}.json");

        // User2 tries to buy an NFT without sending 0.1 ETH (should fail)
        vm.prank(user2);
        fundNFT.buyNFT(1); // Should revert since no ETH is sent
    }

    function testFailBuyNFTWhenNoSupply() public {
        uint256 nftSupply = 1;

        // Owner creates a new fund with only 1 NFT available
        fundNFT.createFund(nftSupply, "https://mybaseuri.com/fund1/{id}.json");

        // User1 buys the first NFT
        vm.prank(user1);
        fundNFT.buyNFT{value: 0.05 ether}(1);

        // User2 tries to buy another NFT from the same fund (should fail as supply is 0)
        vm.prank(user2);
        fundNFT.buyNFT{value: 0.05 ether}(1); // Should fail
    }

    // // Test constructing metadata URL
    // function testConstructMetadataURL() public {
    //     uint256 nftSupply = 10; // For example, create 10 NFTs
    //     uint256 fundId = fundNFT.createFund(
    //         nftSupply,
    //         "https://mybaseuri.com/fund1/{id}.json"
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
        fundNFT.createFund(10, "https://mybaseuri.com/fund1/{id}.json"); // Creates a fund with 10 NFTs
        uint256 tokenId = fundNFT.getCurrentTokenId();

        // Verify that the current token ID matches the expected value
        assertEq(tokenId, 1); // Assuming the first tokenId is 1 when the contract is deployed
    }

    // Test getNFTPrice
    function testGetNFTPrice() public {
        uint256 nftPrice = fundNFT.getNFTPrice();

        // Verify that the NFT price matches the expected value
        assertEq(nftPrice, 0.05 ether); // Assuming the NFT price is set to 0.05 ether in the contract
    }

    // Test getCurrentFundId
    function testGetCurrentFundId() public {
        fundNFT.createFund(10, "https://mybaseuri.com/fund1/{id}.json"); // Creates a fund with 10 NFTs
        uint256 fundId = fundNFT.getCurrentFundId();

        // Verify that the current fund ID matches the expected value
        assertEq(fundId, 1); // Assuming the first fundId is 1 when the contract is deployed
    }

    // Test getFundDetails
    function testGetFundDetails() public {
        uint256 nftSupply = 10;
        string memory fundBaseURI = "https://mybaseuri.com/fund1/{id}.json";

        // Owner creates a new fund
        fundNFT.createFund(nftSupply, fundBaseURI);

        // Get details of the created fund
        (
            uint256 tokenId,
            uint256 totalSupply,
            uint256 availableSupply,
            string memory baseURI
        ) = fundNFT.getFundDetails(1);

        // Verify that the fund details are correct
        assertEq(tokenId, 1); // Token ID should be 1
        assertEq(totalSupply, nftSupply); // Total supply should match the input
        assertEq(availableSupply, nftSupply); // Available supply should also match
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

    function uint2str(
        uint256 _i
    ) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 length;
        while (j != 0) {
            length++;
            j /= 10;
        }
        bytes memory bstr = new bytes(length);
        uint256 k = length;
        j = _i;
        while (j != 0) {
            bstr[--k] = bytes1(uint8(48 + (j % 10)));
            j /= 10;
        }
        return string(bstr);
    }

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
