// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC1155} from "lib/openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol"; // Import the Strings library
import {IERC1155Receiver, IERC165} from "lib/openzeppelin-contracts/contracts//token/ERC1155/IERC1155Receiver.sol";

contract FundNFT is ERC1155, IERC1155Receiver {
    uint256 private currentTokenId; // Token ID counter
    uint256 private constant NFT_PRICE = 0.05 ether; // Price of 1 NFT in ETH
    address private owner; // Owner of the contract

    string private baseURI; // The base URI to the metadata folder (Pinata IPFS URL)

    struct Fund {
        uint256 tokenId; // Token ID associated with the fund
        uint256 totalSupply; // Total number of NFTs allocated for the fund
        uint256 availableSupply; // Number of NFTs still available for purchase
        string baseURI; // Base URI for this specific fund
    }

    mapping(uint256 => Fund) private funds; // Mapping of fund ID to Fund details
    uint256 private currentFundId; // Fund ID counter

    event FundCreated(
        uint256 indexed fundId,
        uint256 indexed tokenId,
        uint256 totalSupply,
        string baseURI
    );
    event NFTPurchased(
        address indexed buyer,
        uint256 indexed fundId,
        uint256 indexed tokenId,
        uint256 amount
    );

    // Custom onlyOwner modifier
    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }

    constructor(string memory initialBaseURI) ERC1155(initialBaseURI) {
        owner = msg.sender; // Set the owner to the deployer's address
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
    ) public view virtual override(ERC1155, IERC165) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // Function to create a new fund with a specified number of NFTs
    function createFund(
        uint256 nftSupply,
        string memory fundBaseURI
    ) external onlyOwner returns (uint256) {
        require(nftSupply > 0, "NFT supply must be greater than zero");

        uint256 newTokenId = currentTokenId += 1; // Increment token ID for the new fund
        currentTokenId = newTokenId;
        currentFundId += 1; // Increment fund ID

        // Create a new fund
        funds[currentFundId] = Fund({
            tokenId: currentTokenId,
            totalSupply: nftSupply,
            availableSupply: nftSupply,
            baseURI: fundBaseURI
        });

        // Mint all NFTs for the owner (admin) initially, as these represent the fund
        _mint(address(this), currentTokenId, nftSupply, "");

        emit FundCreated(currentFundId, currentTokenId, nftSupply, fundBaseURI);
        return currentFundId; // Return the new fund's ID
    }

    // Function to allow investors to swap 0.05 ETH for an NFT of a specific fund
    function buyNFT(uint256 fundId) external payable {
        require(fundId > 0 && fundId <= currentFundId, "Invalid fund ID");
        Fund storage fund = funds[fundId];
        require(fund.availableSupply > 0, "No NFTs available for this fund");
        require(
            msg.value >= NFT_PRICE,
            "should send 0.05 ETH to purchase an NFT"
        );

        // Transfer one NFT from the owner's balance to the buyer
        fund.availableSupply -= 1; // Decrease the available supply for the fund
        _safeTransferFrom(address(this), msg.sender, fund.tokenId, 1, ""); // Transfer 1 NFT to buyer

        emit NFTPurchased(msg.sender, fundId, fund.tokenId, 1);
    }

    // Function to withdraw ETH collected from NFT sales
    function withdrawFunds() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds available for withdrawal");

        (bool success, ) = payable(msg.sender).call{value: balance}("");
        require(success, "Transfer failed.");
    }

    // Function to set a new base URI for metadata (if needed)
    function setBaseURI(
        uint256 fundId,
        string memory newBaseURI
    ) external onlyOwner {
        require(fundId > 0 && fundId <= currentFundId, "Invalid fund ID");
        Fund storage fund = funds[fundId];
        fund.baseURI = newBaseURI;
        _setURI(newBaseURI);
    }

    // Function to construct the metadata URL based on the base URI and token ID
    function constructMetadataURL(
        uint256 fundId,
        uint256 tokenId
    ) public view returns (string memory) {
        require(fundId > 0 && fundId <= currentFundId, "Invalid fund ID");
        Fund storage fund = funds[fundId];
        require(
            tokenId == fund.tokenId,
            "Token ID does not match the fund's token ID"
        );
        // Ensure baseURI is set correctly

        require(bytes(baseURI).length > 0, "Base URI is empty");

        // require(tokenId > 0 && tokenId <= currentTokenId, "Invalid token ID");
        string memory slash = bytes(baseURI)[bytes(baseURI).length - 1] == "/"
            ? ""
            : "/";
        return
            string(
                abi.encodePacked(
                    baseURI,
                    slash,
                    Strings.toString(tokenId),
                    ".json"
                )
            );
    }

    // Getter function for currentTokenId
    function getCurrentTokenId() external view returns (uint256) {
        return currentTokenId;
    }

    // Getter function for NFT price
    function getNFTPrice() external pure returns (uint256) {
        return NFT_PRICE;
    }

    // Getter function for currentFundId
    function getCurrentFundId() external view returns (uint256) {
        return currentFundId;
    }

    // Getter function for fund details
    function getFundDetails(
        uint256 fundId
    )
        external
        view
        returns (
            uint256 tokenId,
            uint256 totalSupply,
            uint256 availableSupply,
            string memory fundBaseURI
        )
    {
        require(fundId > 0 && fundId <= currentFundId, "Invalid fund ID");
        Fund storage fund = funds[fundId];
        return (
            fund.tokenId,
            fund.totalSupply,
            fund.availableSupply,
            fund.baseURI
        );
    }

    function getMetadataURL(
        uint256 fundId,
        uint256 tokenId
    ) external view returns (string memory) {
        return constructMetadataURL(fundId, tokenId);
    }
}
